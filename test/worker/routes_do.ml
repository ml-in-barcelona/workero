open Workero
module D = Durable_object
module Js = Js_of_ocaml.Js

let query req name = URL.query (Request.url req) name

let required req name =
  match query req name with
  | Some v -> v
  | None -> invalid_arg ("missing query " ^ name)

let flag req name = Option.map (( = ) "true") (query req name)

let op req =
  String.sub (Request.path req) 1 (String.length (Request.path req) - 1)

let count_of = function Some (`Int n) -> n | _ -> 0
let ok text = Response.text text

let counter state _env =
  let storage = D.State.storage state in
  let count = ref 0 in
  let bump key =
    let n = count_of (D.Storage.get storage key) + 1 in
    D.Storage.put storage key (`Int n);
    n
  in
  D.make
    ~init:(fun () ->
      ignore (bump "creations");
      count := count_of (D.Storage.get storage "count"))
    ~fetch:(fun req ->
      match op req with
      | "incr" ->
          incr count;
          D.Storage.put storage "count" (`Int !count);
          ok (string_of_int !count)
      | "get" -> ok (string_of_int !count)
      | "stored" -> (
          match D.Storage.get storage (required req "key") with
          | value -> ok (Option.fold ~none:"none" ~some:Jsonkit.to_string value)
          | exception Invalid_argument _ -> ok "Invalid_argument")
      | "creations" ->
          ok (string_of_int (count_of (D.Storage.get storage "creations")))
      | "id" ->
          let id = D.State.id state in
          ok
            (Printf.sprintf "%s|%s"
               (Option.value (D.Id.name id) ~default:"none")
               (D.Id.to_string id))
      | "kv-put" ->
          D.Storage.put storage (required req "key")
            (Jsonkit.of_string (required req "value"));
          ok "put"
      | "kv-delete" ->
          ok (string_of_bool (D.Storage.delete storage (required req "key")))
      | "kv-list" ->
          let entries =
            D.Storage.list ?prefix:(query req "prefix")
              ?start:(query req "start") ?end_:(query req "end")
              ?reverse:(flag req "reverse")
              ?limit:(Option.map int_of_string (query req "limit"))
              storage
          in
          ok
            (String.concat ","
               (List.map (fun (k, v) -> k ^ "=" ^ Jsonkit.to_string v) entries))
      | "delete-all" ->
          D.Storage.delete_all storage;
          ok "deleted"
      | "sync" ->
          D.Storage.sync storage;
          ok "synced"
      | "bcw" ->
          ok
            (D.State.block_concurrency_while state (fun () ->
                 Promise.await (Timer.sleep 20);
                 "after await"))
      | "bcw-raises" -> (
          match
            D.State.block_concurrency_while state (fun () ->
                failwith "reset me")
          with
          | _ -> ok "no raise"
          | exception Failure message -> ok ("Failure " ^ message))
      | "wait-until" ->
          D.State.wait_until state (fun () ->
              Promise.await (Timer.sleep 50);
              D.Storage.put storage "background" (`String "done"));
          ok "scheduled"
      | "raw-put" ->
          let kv = Js.Unsafe.get (D.Storage.to_js storage) "kv" in
          let global name = Js.Unsafe.get Js.Unsafe.global name in
          let number n = Js.Unsafe.inject (Js.number_of_float n) in
          let value =
            match required req "kind" with
            | "date" -> Js.Unsafe.new_obj (global "Date") [| number 0. |]
            | "map" -> Js.Unsafe.new_obj (global "Map") [||]
            | "bigint" -> Js.Unsafe.fun_call (global "BigInt") [| number 10. |]
            | _ ->
                let o = Js.Unsafe.obj [||] in
                Js.Unsafe.set o "self" (Js.Unsafe.inject o);
                Js.Unsafe.inject o
          in
          ignore
            (Js.Unsafe.meth_call kv "put"
               [| Js.Unsafe.inject (Js.string "raw"); value |]);
          ok "put"
      | other -> Response.text ~status:`Not_Found other)
    ()

let alarms state _env =
  let storage = D.State.storage state in
  let bump key =
    D.Storage.put storage key (`Int (count_of (D.Storage.get storage key) + 1))
  in
  D.make
    ~alarm:(fun info ->
      bump "attempts";
      D.Storage.put storage "last"
        (`String (Printf.sprintf "%d:%b" info.retry_count info.is_retry));
      if
        D.Storage.get storage "mode" = Some (`String "fail-once")
        && info.retry_count = 0
      then failwith "alarm boom";
      bump "fired")
    ~fetch:(fun req ->
      let allow_concurrency = flag req "allow_concurrency" in
      let allow_unconfirmed = flag req "allow_unconfirmed" in
      match op req with
      | "set" ->
          D.Storage.set_alarm_after ?allow_concurrency ?allow_unconfirmed
            storage
            ~ms:(float_of_string (required req "ms"));
          ok "set"
      | "set-at" ->
          D.Storage.set_alarm ?allow_concurrency ?allow_unconfirmed storage
            ~at:(float_of_string (required req "at"));
          ok "set"
      | "get" ->
          ok
            (Option.fold ~none:"none" ~some:(Printf.sprintf "%.0f")
               (D.Storage.get_alarm storage))
      | "delete" ->
          D.Storage.delete_alarm storage;
          ok "deleted"
      | "mode" ->
          D.Storage.put storage "mode" (`String (required req "value"));
          ok "mode set"
      | "status" ->
          let n key = count_of (D.Storage.get storage key) in
          ok
            (Printf.sprintf "fired=%d attempts=%d last=%s" (n "fired")
               (n "attempts")
               (match D.Storage.get storage "last" with
               | Some (`String s) -> s
               | _ -> "none"))
      | other -> Response.text ~status:`Not_Found other)
    ()

let () =
  D.register "Counter" counter;
  D.register "class" counter;
  D.register "WorkeroDurableObject" counter;
  D.register "Alarms" alarms;
  D.register "NoFetch" (fun _ _ -> D.make ~alarm:(fun _ -> ()) ());
  D.register "Awaiting" (fun _ _ ->
      Promise.await (Promise.resolve ());
      D.make ~fetch:(fun _ -> ok "unreachable") ())

let show res =
  Printf.sprintf "%d|%s" (Response.status res) (Response.body_text res)

let handle req env _ctx =
  let segments = String.split_on_char '/' (Request.path req) in
  match segments with
  | [ ""; "do"; binding; name; op ] -> (
      let namespace = D.Namespace.of_env env binding in
      let stub = D.Namespace.get_by_name namespace name in
      let query = Request.query_string req in
      let url =
        Printf.sprintf "http://do/%s%s" op
          (if query = "" then "" else "?" ^ query)
      in
      match Fetcher.fetch stub url with
      | res -> Some (Response.text (show res))
      | exception Js_error e ->
          Some (Response.text ~status:`Bad_Gateway (Promise.error_to_string e)))
  | [ ""; "do-ns"; op ] -> (
      let url = Request.url req in
      let q name = Option.value (URL.query url name) ~default:"" in
      let namespace () = D.Namespace.of_env env (q "binding") in
      match op with
      | "id" ->
          let ns = namespace () in
          let id = D.Namespace.id_from_name ns (q "name") in
          let again = D.Namespace.id_from_name ns (q "name") in
          let other = D.Namespace.id_from_name ns (q "name" ^ "-other") in
          let restored = D.Namespace.id_from_string ns (D.Id.to_string id) in
          Some
            (Response.text
               (Printf.sprintf "len=%d name=%s same=%b other=%b restored=%b"
                  (String.length (D.Id.to_string id))
                  (Option.value (D.Id.name id) ~default:"none")
                  (D.Id.equal id again) (D.Id.equal id other)
                  (D.Id.equal id restored)))
      | "unique" ->
          let ns = namespace () in
          let a = D.Namespace.unique_id ns in
          let b = D.Namespace.unique_id ns in
          Some
            (Response.text
               (Printf.sprintf "len=%d name=%s distinct=%b"
                  (String.length (D.Id.to_string a))
                  (Option.value (D.Id.name a) ~default:"none")
                  (not (D.Id.equal a b))))
      | "unique-eu" -> (
          match D.Namespace.unique_id ~jurisdiction:Eu (namespace ()) with
          | _ -> Some (Response.text "no raise")
          | exception Js_error e ->
              Some (Response.text (Promise.error_to_string e)))
      | "unique-stub" ->
          let ns = namespace () in
          let id = D.Namespace.unique_id ns in
          let stub = D.Namespace.get ~location_hint:Weur ns id in
          let first = Fetcher.fetch stub "http://do/incr" in
          let second = Fetcher.fetch (D.Namespace.get ns id) "http://do/incr" in
          Some
            (Response.text
               (Response.body_text first ^ "," ^ Response.body_text second))
      | "bad-string" -> (
          match D.Namespace.id_from_string (namespace ()) "not-an-id" with
          | _ -> Some (Response.text "no raise")
          | exception Js_error _ -> Some (Response.text "Js_error"))
      | "shape" ->
          Some
            (Response.text
               (match namespace () with
               | _ -> "ok"
               | exception Invalid_argument message -> message))
      | _ -> None)
  | _ -> None
