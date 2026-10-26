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
      | "container" ->
          ok
            (match D.State.container state with
            | None -> "none"
            | Some _ -> "some")
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
              Promise.await (Timer.sleep 600);
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

let hex s =
  String.concat ""
    (List.init (String.length s) (fun i ->
         Printf.sprintf "%02x" (Char.code s.[i])))

let show_value = function
  | Sql_value.Null -> "null"
  | Int n -> "i" ^ Int64.to_string n
  | Float f -> Printf.sprintf "f%g" f
  | Text s -> "t" ^ s
  | Blob b -> "b" ^ hex b

let show_row row =
  String.concat "," (List.map (fun (name, v) -> name ^ "=" ^ show_value v) row)

let sqlite state _env =
  let storage = D.State.storage state in
  let sql = D.Storage.sql storage in
  let count () =
    match D.Sql.query sql "SELECT count(*) AS n FROM t" with
    | [ [ ("n", Int n) ] ] -> Int64.to_int n
    | _ -> -1
  in
  let insert id =
    D.Sql.run
      ~params:[ Int id; Text "tx"; Float 0.5; Null ]
      sql "INSERT INTO t VALUES (?, ?, ?, ?)"
  in
  let stored key =
    match D.Storage.get storage key with
    | Some v -> Jsonkit.to_string v
    | None -> "none"
  in
  D.make
    ~fetch:(fun req ->
      match op req with
      | "setup" ->
          ignore
            (D.Sql.run sql
               "CREATE TABLE IF NOT EXISTS t (id INTEGER PRIMARY KEY, name \
                TEXT, score REAL, data BLOB)");
          let written =
            D.Sql.run
              ~params:[ Int 1L; Text "a"; Float 1.5; Blob "\x00\xff" ]
              sql "INSERT INTO t VALUES (?, ?, ?, ?)"
          in
          ignore
            (D.Sql.run
               ~params:[ Int 2L; Null; Float 2.25; Null ]
               sql "INSERT INTO t VALUES (?, ?, ?, ?)");
          ok (string_of_int written)
      | "rows" ->
          ok
            (String.concat ";"
               (List.map show_row
                  (D.Sql.query sql
                     "SELECT id, name, score, data FROM t ORDER BY id")))
      | "numbers" ->
          ok
            (show_row
               (List.hd
                  (D.Sql.query sql
                     "SELECT 2.0 AS real_whole, 1152921504606846976 AS big, \
                      1.5 AS frac")))
      | "update" ->
          ok
            (string_of_int
               (D.Sql.run ~params:[ Text "z" ] sql "UPDATE t SET name = ?"))
      | "big" ->
          let safe = 9007199254740991L in
          ignore (insert safe);
          let read =
            D.Sql.query ~params:[ Int safe ] sql "SELECT id FROM t WHERE id = ?"
          in
          let beyond =
            match insert 9007199254740993L with
            | _ -> "no raise"
            | exception Invalid_argument _ -> "Invalid_argument"
          in
          ok (String.concat ";" (List.map show_row read) ^ "|" ^ beyond)
      | "syntax" -> (
          match D.Sql.query sql "SELEKT 1" with
          | _ -> ok "no raise"
          | exception Js_error e -> ok (Promise.error_to_string e))
      | "size" -> ok (string_of_bool (D.Sql.database_size sql > 0))
      | "tx-commit" ->
          let v =
            D.Storage.transaction_sync storage (fun () ->
                ignore (insert 10L);
                D.Storage.put storage "k" (`Int 1);
                42)
          in
          ok (Printf.sprintf "%d count=%d k=%s" v (count ()) (stored "k"))
      | "tx-rollback" ->
          let outcome =
            match
              D.Storage.transaction_sync storage (fun () ->
                  ignore (insert 11L);
                  D.Storage.put storage "k2" (`Int 1);
                  failwith "boom")
            with
            | _ -> "no raise"
            | exception Failure m -> "Failure " ^ m
          in
          ok
            (Printf.sprintf "%s count=%d k2=%s" outcome (count ()) (stored "k2"))
      | "tx-await" ->
          let outcome =
            match
              D.Storage.transaction_sync storage (fun () ->
                  ignore (insert 12L);
                  Promise.await (Promise.resolve ()))
            with
            | () -> "no raise"
            | exception Invalid_argument m -> m
          in
          ok (Printf.sprintf "%s count=%d" outcome (count ()))
      | "tx-sql-error" ->
          let outcome =
            match
              D.Storage.transaction_sync storage (fun () ->
                  ignore (insert 13L);
                  ignore (D.Sql.query sql "SELEKT"))
            with
            | () -> "no raise"
            | exception Js_error _ -> "Js_error"
          in
          ok (Printf.sprintf "%s count=%d" outcome (count ()))
      | "tx-async-commit" ->
          let v =
            D.Storage.transaction storage (fun _ ->
                ignore (insert 14L);
                Promise.await (Promise.resolve ());
                D.Storage.put storage "ka" (`Int 1);
                43)
          in
          ok (Printf.sprintf "%d count=%d ka=%s" v (count ()) (stored "ka"))
      | "tx-async-rollback" ->
          let outcome =
            match
              D.Storage.transaction storage (fun _ ->
                  ignore (insert 15L);
                  D.Storage.put storage "kb" (`Int 1);
                  Promise.await (Promise.resolve ());
                  failwith "boom")
            with
            | _ -> "no raise"
            | exception Failure m -> "Failure " ^ m
          in
          ok
            (Printf.sprintf "%s count=%d kb=%s" outcome (count ()) (stored "kb"))
      | "tx-async-explicit" ->
          let v =
            D.Storage.transaction storage (fun txn ->
                ignore (insert 16L);
                D.Storage.put storage "kc" (`Int 1);
                Promise.await (Promise.resolve ());
                D.Storage.rollback txn;
                D.Storage.put storage "kd" (`Int 1);
                9)
          in
          ok
            (Printf.sprintf "%d count=%d kc=%s kd=%s" v (count ()) (stored "kc")
               (stored "kd"))
      | "tx-async-nested" ->
          D.Storage.transaction storage (fun _ ->
              D.Storage.put storage "ke" (`Int 1);
              try
                D.Storage.transaction storage (fun _ ->
                    D.Storage.put storage "kf" (`Int 1);
                    Promise.await (Promise.resolve ());
                    failwith "inner")
              with Failure _ -> ());
          ok (Printf.sprintf "ke=%s kf=%s" (stored "ke") (stored "kf"))
      | "tx-async-sql-error" ->
          let outcome =
            match
              D.Storage.transaction storage (fun _ ->
                  ignore (insert 17L);
                  Promise.await (Promise.resolve ());
                  ignore (D.Sql.query sql "SELEKT"))
            with
            | () -> "no raise"
            | exception Js_error _ -> "Js_error"
          in
          ok (Printf.sprintf "%s count=%d" outcome (count ()))
      | other -> Response.text ~status:`Not_Found other)
    ()

let rooms ~hibernating state _env =
  let storage = D.State.storage state in
  D.State.set_websocket_auto_response state ~request:"ping" ~response:"pong";
  let bump key =
    D.Storage.put storage key (`Int (count_of (D.Storage.get storage key) + 1))
  in
  D.make
    ~fetch:(fun req ->
      match op req with
      | "connect" ->
          let { Websocket.client; server } = Websocket.pair () in
          let tags =
            String.split_on_char ','
              (Option.value (query req "tags") ~default:"")
            |> List.filter (( <> ) "")
          in
          D.State.accept_websocket ~tags state server;
          Websocket.response client
      | "handled" ->
          ok (string_of_int (count_of (D.Storage.get storage "handled")))
      | "closed" ->
          ok
            (match D.Storage.get storage "closed" with
            | Some (`String s) -> s
            | _ -> "none")
      | other -> Response.text ~status:`Not_Found other)
    ?websocket_message:
      (if not hibernating then None
       else
         Some
           (fun ws message ->
             bump "handled";
             match message with
             | Websocket.Text "tags" ->
                 Websocket.send ws
                   (Text (String.concat "," (D.State.tags state ws)))
             | Text "peers" ->
                 Websocket.send ws
                   (Text
                      (string_of_int
                         (List.length (D.State.websockets ~tag:"room" state))))
             | Text "broadcast" ->
                 List.iter
                   (fun w -> Websocket.send w (Text "hello all"))
                   (D.State.websockets state)
             | Text s ->
                 let n =
                   match Websocket.deserialize_attachment ws with
                   | Some (`Int n) -> n + 1
                   | _ -> 1
                 in
                 Websocket.serialize_attachment ws (`Int n);
                 Websocket.send ws (Text (Printf.sprintf "%d:%s" n s))
             | Binary b -> Websocket.send ws (Binary (hex b))))
    ?websocket_close:
      (if not hibernating then None
       else
         Some
           (fun ws ~code ~reason ~was_clean ->
             D.Storage.put storage "closed"
               (`String (Printf.sprintf "%d:%s:%b" code reason was_clean));
             Websocket.close ~code:1000 ws))
    ()

let rpc_counter state env =
  let storage = D.State.storage state in
  let get () = count_of (D.Storage.get storage "n") in
  D.make
    ~rpc:(fun name args ->
      match (name, args) with
      | "increment", [] ->
          let n = get () + 1 in
          D.Storage.put storage "n" (`Int n);
          `Int n
      | "add", [ `Int a; `Int b ] -> `Int (a + b)
      | "get", [] -> `Int (get ())
      | "echo", [ v ] -> v
      | "nothing", [] -> `Null
      | "fail", [ `String message ] -> failwith message
      | "slow", [] ->
          Promise.await (Timer.sleep 20);
          `String "slept"
      | _ -> (
          match
            Rpc_values.answer
              ~stub:(fun () -> Fetcher.of_env env "BACKEND")
              ~spawn:(D.State.wait_until state) name args
          with
          | Some v -> v
          | None -> invalid_arg ("bad RPC call " ^ name)))
    ~fetch:(fun _ -> Response.text "rpc object")
    ()

let () =
  D.register
    ~rpc:
      ([ "increment"; "add"; "get"; "echo"; "nothing"; "fail"; "slow" ]
      @ Rpc_values.methods)
    "Rpc" rpc_counter;
  D.register ~rpc:[ "ping" ] "RpcNoHandler" (fun _ _ -> D.make ());
  D.register "Sqlite" sqlite;
  D.register "Rooms" (rooms ~hibernating:true);
  D.register "NoWsHandler" (rooms ~hibernating:false);
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

let container_stub log =
  let open Js.Unsafe in
  let g name = get global (Js.string name) in
  let num v = int_of_float (Js.float_of_number (coerce v)) in
  let record entry = log := entry :: !log in
  let promise m arg = meth_call (g "Promise") m [| arg |] in
  let c = obj [||] in
  set c (Js.string "start")
    (inject
       (Js.Unsafe.callback_with_arity 1 (fun options ->
            record
              ("start:"
              ^ Js.to_string
                  (meth_call (g "JSON") "stringify" [| inject options |]));
            ())));
  set c (Js.string "monitor")
    (inject
       (Js.Unsafe.callback_with_arity 1 (fun () ->
            record "monitor";
            promise "reject"
              (new_obj (g "Error") [| inject (Js.string "exit 3") |]))));
  set c (Js.string "destroy")
    (inject
       (Js.Unsafe.callback_with_arity 1 (fun error ->
            record
              ("destroy:"
              ^
              if Js.Optdef.test error then
                Js.to_string (get error (Js.string "message"))
              else "-");
            promise "resolve" (inject Js.undefined))));
  set c (Js.string "signal")
    (inject
       (Js.Unsafe.callback_with_arity 1 (fun n ->
            record ("signal:" ^ string_of_int (num n)))));
  let recorded name f =
    set c (Js.string name)
      (inject
         (Js.Unsafe.callback_with_arity 2 (fun a b ->
              record (f a b);
              promise "resolve" (inject Js.undefined))))
  in
  let tag binding = Js.to_string (get binding (Js.string "tag")) in
  recorded "setInactivityTimeout" (fun ms _ ->
      "timeout:" ^ string_of_int (num ms));
  recorded "interceptOutboundHttp" (fun addr binding ->
      "http:" ^ Js.to_string addr ^ ":" ^ tag binding);
  recorded "interceptOutboundHttps" (fun addr binding ->
      "https:" ^ Js.to_string addr ^ ":" ^ tag binding);
  set c
    (Js.string "interceptAllOutboundHttp")
    (inject
       (Js.Unsafe.callback_with_arity 1 (fun binding ->
            record ("all:" ^ tag binding);
            promise "resolve" (inject Js.undefined))));
  set c (Js.string "getTcpPort")
    (inject
       (Js.Unsafe.callback_with_arity 1 (fun port ->
            let tcp = obj [||] in
            set tcp (Js.string "connect")
              (inject
                 (Js.Unsafe.callback_with_arity 1 (fun address ->
                      record
                        (Printf.sprintf "connect:%d:%s" (num port)
                           (Js.to_string address));
                      let echo =
                        new_obj (g "TransformStream")
                          [|
                            inject (obj [||]);
                            inject (obj [||]);
                            inject (obj [| ("highWaterMark", inject 16) |]);
                          |]
                      in
                      let socket = obj [||] in
                      set socket (Js.string "opened")
                        (promise "resolve" (inject (obj [||])));
                      set socket (Js.string "readable")
                        (get echo (Js.string "readable"));
                      set socket (Js.string "writable")
                        (get echo (Js.string "writable"));
                      socket)));
            set tcp (Js.string "fetch")
              (inject
                 (Js.Unsafe.callback_with_arity 1 (fun url ->
                      promise "resolve"
                        (new_obj (g "Response")
                           [|
                             inject
                               (Js.string
                                  (Printf.sprintf "port %d %s" (num port)
                                     (Js.to_string url)));
                           |]))));
            tcp)));
  Js.Unsafe.set c (Js.string "running") (Js.bool false);
  c

let container_probe () =
  let log = ref [] in
  let c = container_stub log in
  let ctx = Js.Unsafe.obj [| ("container", Js.Unsafe.inject c) |] in
  let state = D.State.of_js (Js.Unsafe.inject ctx) in
  let container = Option.get (D.State.container state) in
  D.Container.start ~entrypoint:[ "sh"; "-c"; "x" ]
    ~env:[ ("A", "1") ]
    ~enable_internet:true container;
  D.Container.start container;
  let monitored =
    match D.Container.monitor container with
    | () -> "no raise"
    | exception Js_error e -> Promise.error_to_string e
  in
  D.Container.signal container 15;
  let tcp = D.Container.get_tcp_port container 8080 in
  let body = Response.body_text (Fetcher.fetch tcp "http://container/x") in
  D.Container.destroy ~message:"bye" container;
  D.Container.destroy container;
  let socket = D.Container.connect container ~port:9000 in
  ignore (Socket.opened socket);
  let writer = Socket.writer socket in
  Stream.Writer.write writer "ping";
  Stream.Writer.close writer;
  let echoed = Stream.Reader.read (Socket.reader socket) in
  D.Container.set_inactivity_timeout container ~ms:60_000;
  let binding tag =
    Fetcher.of_js
      (Js.Unsafe.obj [| ("tag", Js.Unsafe.inject (Js.string tag)) |])
  in
  D.Container.intercept_outbound_http container "*.example.com" (binding "a");
  D.Container.intercept_all_outbound_http container (binding "b");
  D.Container.intercept_outbound_https container "*" (binding "c");
  let invalid f =
    match f () with
    | () -> "no raise"
    | exception Invalid_argument _ -> "invalid"
  in
  let invalids =
    String.concat ","
      [
        invalid (fun () -> D.Container.set_inactivity_timeout container ~ms:0);
        invalid (fun () ->
            D.Container.set_inactivity_timeout container ~ms:21_600_001);
        invalid (fun () -> ignore (D.Container.connect container ~port:0));
      ]
  in
  Printf.sprintf "%s|%s|%s|%s|%s"
    (String.concat ";" (List.rev !log))
    monitored body
    (Option.value echoed ~default:"-")
    invalids

let handle req env _ctx =
  let segments = String.split_on_char '/' (Request.path req) in
  match segments with
  | [ ""; "do-container-stub" ] -> Some (Response.text (container_probe ()))
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
  | [ ""; "do-rpc"; binding; name; meth ] -> (
      let namespace = D.Namespace.of_env env binding in
      let stub = D.Namespace.get_by_name namespace name in
      let args =
        match query req "args" with
        | None -> []
        | Some text -> (
            match Jsonkit.of_string text with
            | `List l -> List.map Rpc.of_json l
            | _ -> invalid_arg "args must be a JSON array")
      in
      match D.call stub meth args with
      | v -> Some (Response.text (Rpc_values.text v))
      | exception Js_error e ->
          Some (Response.text ~status:`Bad_Gateway (Promise.error_to_string e)))
  | [ ""; "do-ws"; binding; name; op ] ->
      let namespace = D.Namespace.of_env env binding in
      let stub = D.Namespace.get_by_name namespace name in
      let query = Request.query_string req in
      let url =
        Printf.sprintf "http://do/%s%s" op
          (if query = "" then "" else "?" ^ query)
      in
      Some (Fetcher.fetch ~headers:[ ("upgrade", "websocket") ] stub url)
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
