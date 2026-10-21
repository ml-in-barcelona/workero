module Js = Js_of_ocaml.Js
open Internal

let flushing f = Fun.protect ~finally:flush_all f
let undefined = Js.Unsafe.inject Js.undefined
let bool_js b = Js.Unsafe.inject (Js.bool b)
let to_bool v = Js.to_bool (Js.Unsafe.coerce v)
let to_float v = Js.float_of_number (Js.Unsafe.coerce v)

let throw message =
  Js.Js_error.raise_
    (Js.Js_error.of_error
       (Js.Unsafe.coerce (Js.Unsafe.new_obj (global "Error") [| str message |])))

module Id = struct
  type t = js

  let to_string id =
    Js.to_string (Js.Unsafe.coerce (Binding.invoke id "toString" [||]))

  let name id = get_string id "name"
  let equal a b = to_bool (Binding.invoke a "equals" [| b |])
  let of_js (v : js) : t = v
  let to_js (t : t) : js = t
end

module Storage = struct
  type t = js

  let kv t = Js.Unsafe.get t "kv"

  let get t key =
    let v = Binding.invoke (kv t) "get" [| str key |] in
    if typeof v = "undefined" then None else Some (Json_js.of_js v)

  let put t key value =
    ignore (Binding.invoke (kv t) "put" [| str key; Json_js.to_js value |])

  let delete t key = to_bool (Binding.invoke (kv t) "delete" [| str key |])

  let list ?prefix ?start ?end_ ?reverse ?limit t =
    let field name f = Option.map (fun v -> (name, f v)) in
    let options =
      Binding.options
        (List.filter_map Fun.id
           [
             field "prefix" str prefix;
             field "start" str start;
             field "end" str end_;
             field "reverse" bool_js reverse;
             field "limit"
               (fun n -> Js.Unsafe.inject (Js.number_of_float (float_of_int n)))
               limit;
           ])
    in
    let entries =
      meth (global "Array") "from"
        [| Binding.invoke (kv t) "list" [| options |] |]
    in
    List.init
      (int_of_js (Js.Unsafe.get entries "length"))
      (fun i ->
        let entry = Js.Unsafe.get entries i in
        ( Js.to_string (Js.Unsafe.coerce (Js.Unsafe.get entry 0)),
          Json_js.of_js (Js.Unsafe.get entry 1) ))

  let delete_all t = Binding.call ~decode:Decode.unit t "deleteAll" [||]
  let sync t = Binding.call ~decode:Decode.unit t "sync" [||]
  let get_alarm t = Binding.call_opt ~decode:Decode.float t "getAlarm" [||]

  let alarm_options ?allow_concurrency ?allow_unconfirmed () =
    let field name = Option.map (fun v -> (name, bool_js v)) in
    Binding.options
      (List.filter_map Fun.id
         [
           field "allowConcurrency" allow_concurrency;
           field "allowUnconfirmed" allow_unconfirmed;
         ])

  let set_alarm ?allow_concurrency ?allow_unconfirmed t ~at =
    Binding.call ~decode:Decode.unit t "setAlarm"
      [|
        Js.Unsafe.inject (Js.number_of_float at);
        alarm_options ?allow_concurrency ?allow_unconfirmed ();
      |]

  let set_alarm_after ?allow_concurrency ?allow_unconfirmed t ~ms =
    set_alarm ?allow_concurrency ?allow_unconfirmed t ~at:(Date.now () +. ms)

  let delete_alarm t = Binding.call ~decode:Decode.unit t "deleteAlarm" [||]
  let of_js (v : js) : t = v
  let to_js (t : t) : js = t
end

module State = struct
  type t = js

  let id t = Id.of_js (Js.Unsafe.get t "id")
  let storage t = Storage.of_js (Js.Unsafe.get t "storage")
  let wait_until t f = Context.wait_until (Context.of_js t) f

  let block_concurrency_while t f =
    let result = ref None in
    let work =
      Async.promising (fun () : js ->
          Async.run (fun () ->
              result := Some (f ());
              undefined))
    in
    Binding.call ~decode:Decode.unit t "blockConcurrencyWhile" [| work |];
    Option.get !result

  let of_js (v : js) : t = v
  let to_js (t : t) : js = t
end

type alarm_info = { retry_count : int; is_retry : bool }

type t = {
  init : (unit -> unit) option;
  fetch : (Request.t -> Response.t) option;
  alarm : (alarm_info -> unit) option;
}

let make ?init ?fetch ?alarm () = { init; fetch; alarm }

let alarm_info_of_js info =
  if typeof info <> "object" || is_nullish info then
    { retry_count = 0; is_retry = false }
  else
    {
      retry_count = Option.value (get_int info "retryCount") ~default:0;
      is_retry =
        typeof (Js.Unsafe.get info "isRetry") = "boolean"
        && to_bool (Js.Unsafe.get info "isRetry");
    }

let handlers_js t =
  let field name f = Option.map (fun f -> (name, Async.promising (f : _))) f in
  let fields =
    [
      field "init"
        (Option.map
           (fun init () : js ->
             Async.run (fun () ->
                 flushing init;
                 undefined))
           t.init);
      field "fetch"
        (Option.map
           (fun fetch request : js ->
             Async.run (fun () ->
                 flushing (fun () ->
                     Response.to_js (fetch (Request.of_js request)))))
           t.fetch);
      field "alarm"
        (Option.map
           (fun alarm info : js ->
             Async.run (fun () ->
                 flushing (fun () ->
                     alarm (alarm_info_of_js info);
                     undefined)))
           t.alarm);
    ]
  in
  Js.Unsafe.obj (Array.of_list (List.filter_map Fun.id fields))

let is_class_name name =
  name <> ""
  && (match name.[0] with '0' .. '9' -> false | _ -> true)
  && (not (List.mem name [ "default"; "then"; "__proto__" ]))
  && String.for_all
       (function
         | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '$' -> true | _ -> false)
       name

let classes () =
  let root = Registry.root () in
  if typeof (Js.Unsafe.get root "durable_objects") = "undefined" then
    Js.Unsafe.set root "durable_objects" (Js.Unsafe.obj [||]);
  Js.Unsafe.get root "durable_objects"

let register name create =
  let who = "Workero.Durable_object.register" in
  if not (is_class_name name) then
    invalid_arg (Printf.sprintf "%s: %S is not a valid class name" who name);
  let classes = classes () in
  if has_own classes name then
    invalid_arg (Printf.sprintf "%s: class %S is already registered" who name);
  let factory state env : js =
    match
      Async.no_await ~who:(who ^ " create function") (fun () ->
          create (State.of_js state) (Env.of_js env))
    with
    | t -> handlers_js t
    | exception e ->
        throw
          (Printf.sprintf "workero: creating Durable Object %s failed: %s" name
             (Printexc.to_string e))
  in
  Js.Unsafe.set classes name (Js.Unsafe.inject (Js.wrap_callback factory))

module Namespace = struct
  type t = js
  type location_hint = Wnam | Enam | Sam | Weur | Eeur | Apac | Oc | Afr | Me
  type jurisdiction = Eu | Fedramp

  let of_env env name =
    Binding.of_env ~who:"Workero.Durable_object.Namespace.of_env"
      ~what:"a Durable Object namespace"
      ~methods:[ "idFromName"; "idFromString"; "newUniqueId"; "get" ]
      env name

  let id_from_name ns name = Binding.invoke ns "idFromName" [| str name |]
  let id_from_string ns s = Binding.invoke ns "idFromString" [| str s |]
  let jurisdiction_name = function Eu -> "eu" | Fedramp -> "fedramp"

  let unique_id ?jurisdiction ns =
    let args =
      match jurisdiction with
      | None -> [||]
      | Some j ->
          [| Binding.options [ ("jurisdiction", str (jurisdiction_name j)) ] |]
    in
    Binding.invoke ns "newUniqueId" args

  let hint_name = function
    | Wnam -> "wnam"
    | Enam -> "enam"
    | Sam -> "sam"
    | Weur -> "weur"
    | Eeur -> "eeur"
    | Apac -> "apac"
    | Oc -> "oc"
    | Afr -> "afr"
    | Me -> "me"

  let get ?location_hint ns id =
    let args =
      match location_hint with
      | None -> [| id |]
      | Some h ->
          [| id; Binding.options [ ("locationHint", str (hint_name h)) ] |]
    in
    Fetcher.of_js (Binding.invoke ns "get" args)

  let get_by_name ?location_hint ns name =
    get ?location_hint ns (id_from_name ns name)
end
