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

module Sql = struct
  type t = js

  let run_cursor t sql params =
    let args = Array.of_list (str sql :: List.map Sql_value.to_js params) in
    let cursor = Binding.invoke t "exec" args in
    let rows =
      Binding.guard (fun () ->
          meth (global "Array") "from" [| meth cursor "raw" [||] |])
    in
    (cursor, rows)

  let query ?(params = []) t sql =
    let cursor, rows = run_cursor t sql params in
    let names = Decode.(list string) (Js.Unsafe.get cursor "columnNames") in
    List.map
      (fun row -> List.combine names (Decode.(list Sql_value.of_js) row))
      (Decode.(list js) rows)

  let run ?(params = []) t sql =
    let cursor, _ = run_cursor t sql params in
    int_of_js (Js.Unsafe.get cursor "rowsWritten")

  let database_size t = int_of_js (Js.Unsafe.get t "databaseSize")
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

  let sql t = Sql.of_js (Js.Unsafe.get t "sql")

  let transaction_sync t f =
    let result = ref None in
    let work () : js =
      Async.no_await ~who:"Workero.Durable_object.Storage.transaction_sync"
        (fun () -> result := Some (f ()));
      undefined
    in
    ignore
      (Binding.invoke t "transactionSync"
         [| Js.Unsafe.inject (Js.wrap_callback work) |]);
    Option.get !result

  type transaction = js

  let transaction t f =
    let result = ref None in
    let work =
      Async.promising (fun (txn : js) : js ->
          Async.run (fun () ->
              result := Some (f txn);
              undefined))
    in
    Binding.call ~decode:Decode.unit t "transaction" [| work |];
    Option.get !result

  let rollback txn = ignore (Binding.invoke txn "rollback" [||])
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

module Container = struct
  type t = js

  let number n = Js.Unsafe.inject (Js.number_of_float (float_of_int n))

  let strings l =
    Js.Unsafe.inject (Js.array (Array.of_list (List.map Js.string l)))

  let string_map kvs = Binding.options (List.map (fun (k, v) -> (k, str v)) kvs)
  let field name f = Option.map (fun v -> (name, f v))

  let entries obj =
    Decode.(
      list (fun pair ->
          (string (Js.Unsafe.get pair "0"), string (Js.Unsafe.get pair "1"))))
      (meth (global "Object") "entries" [| obj |])

  module Snapshot = struct
    type t = { id : string; size : int; name : string option }

    let of_js v =
      Decode.
        {
          id = field "id" string v;
          size = field "size" int v;
          name = field "name" (option string) v;
        }

    let to_js t =
      Binding.options
        (("id", str t.id)
        :: ("size", number t.size)
        :: List.filter_map Fun.id [ field "name" str t.name ])
  end

  module Directory_snapshot = struct
    type t = { id : string; size : int; dir : string; name : string option }
    type restore = { snapshot : t; mount_point : string option }

    let of_js v =
      Decode.
        {
          id = field "id" string v;
          size = field "size" int v;
          dir = field "dir" string v;
          name = field "name" (option string) v;
        }

    let to_js t =
      Binding.options
        (("id", str t.id)
        :: ("size", number t.size)
        :: ("dir", str t.dir)
        :: List.filter_map Fun.id [ field "name" str t.name ])

    let restore_to_js r =
      Binding.options
        (("snapshot", Js.Unsafe.inject (to_js r.snapshot))
        :: List.filter_map Fun.id [ field "mountPoint" str r.mount_point ])
  end

  type info = { labels : (string * string) list; image : string }

  let running t = to_bool (Js.Unsafe.get t "running")

  let start ?entrypoint ?env ?enable_internet ?container_snapshot
      ?directory_snapshots t =
    let options =
      Binding.options
        (List.filter_map Fun.id
           [
             field "entrypoint" strings entrypoint;
             field "env" string_map env;
             field "enableInternet" bool_js enable_internet;
             field "containerSnapshot" Snapshot.to_js container_snapshot;
             field "directorySnapshots"
               (fun l ->
                 Js.Unsafe.inject
                   (Js.array
                      (Array.of_list
                         (List.map Directory_snapshot.restore_to_js l))))
               directory_snapshots;
           ])
    in
    ignore (Binding.invoke t "start" [| options |])

  let monitor t = Binding.call ~decode:Decode.unit t "monitor" [||]

  let destroy ?message t =
    let args =
      match message with
      | None -> [||]
      | Some m -> [| Js.Unsafe.new_obj (global "Error") [| str m |] |]
    in
    Binding.call ~decode:Decode.unit t "destroy" args

  let signal t signo =
    ignore
      (Binding.invoke t "signal"
         [| Js.Unsafe.inject (Js.number_of_float (float_of_int signo)) |])

  let get_tcp_port t port =
    Fetcher.of_js
      (Binding.invoke t "getTcpPort"
         [| Js.Unsafe.inject (Js.number_of_float (float_of_int port)) |])

  let connect t ~port =
    if port < 1 || port > 65535 then
      invalid_arg
        (Printf.sprintf
           "Workero.Durable_object.Container.connect: port %d is outside 1 to \
            65535"
           port);
    let tcp =
      Binding.invoke t "getTcpPort"
        [| Js.Unsafe.inject (Js.number_of_float (float_of_int port)) |]
    in
    Socket.of_js
      (Binding.invoke tcp "connect"
         [| str (Printf.sprintf "10.0.0.1:%d" port) |])

  let max_inactivity_timeout_ms = 21_600_000

  let set_inactivity_timeout t ~ms =
    if ms < 1 || ms > max_inactivity_timeout_ms then
      invalid_arg
        (Printf.sprintf
           "Workero.Durable_object.Container.set_inactivity_timeout: %d ms is \
            outside 1 to %d"
           ms max_inactivity_timeout_ms);
    Binding.call ~decode:Decode.unit t "setInactivityTimeout"
      [| Js.Unsafe.inject (Js.number_of_float (float_of_int ms)) |]

  let intercept_outbound_http t address fetcher =
    Binding.call ~decode:Decode.unit t "interceptOutboundHttp"
      [| str address; Fetcher.to_js fetcher |]

  let intercept_all_outbound_http t fetcher =
    Binding.call ~decode:Decode.unit t "interceptAllOutboundHttp"
      [| Fetcher.to_js fetcher |]

  let intercept_outbound_https t address fetcher =
    Binding.call ~decode:Decode.unit t "interceptOutboundHttps"
      [| str address; Fetcher.to_js fetcher |]

  let intercept_outbound_tcp t address fetcher =
    Binding.call ~decode:Decode.unit t "interceptOutboundTcp"
      [| str address; Fetcher.to_js fetcher |]

  let snapshot_container ?name t =
    let args =
      match name with
      | None -> [||]
      | Some n -> [| Js.Unsafe.inject (Binding.options [ ("name", str n) ]) |]
    in
    Binding.call ~decode:Snapshot.of_js t "snapshotContainer" args

  let snapshot_directory ?name t ~dir =
    let options =
      Binding.options
        (("dir", str dir) :: List.filter_map Fun.id [ field "name" str name ])
    in
    Binding.call ~decode:Directory_snapshot.of_js t "snapshotDirectory"
      [| Js.Unsafe.inject options |]

  let inspect t =
    Binding.call
      ~decode:
        (Decode.option (fun v ->
             {
               labels = entries (Js.Unsafe.get v "labels");
               image = Decode.(field "image" string) v;
             }))
      t "inspect" [||]

  module Process = struct
    type t = js
    type output = { stdout : string; stderr : string; exit_code : int }

    let pid t = int_of_js (Js.Unsafe.get t "pid")
    let is_pty t = to_bool (Js.Unsafe.get t "isPty")

    let stream t name =
      let v = Js.Unsafe.get t name in
      if is_nullish v then None else Some v

    let stdin t =
      Option.map
        (fun s -> Stream.Writer.of_js (Binding.invoke s "getWriter" [||]))
        (stream t "stdin")

    let stdout t = Option.map Stream.of_js (stream t "stdout")
    let stderr t = Option.map Stream.of_js (stream t "stderr")

    let exit_code t =
      Promise.await
        (Promise.of_js ~decode:Decode.int (Js.Unsafe.get t "exitCode"))

    let output t =
      Binding.call
        ~decode:(fun v ->
          Decode.
            {
              stdout = field "stdout" bytes v;
              stderr = field "stderr" bytes v;
              exit_code = field "exitCode" int v;
            })
        t "output" [||]

    let kill ?signal t =
      let args = match signal with None -> [||] | Some n -> [| number n |] in
      ignore (Binding.invoke t "kill" args)

    let resize t ~cols ~rows =
      ignore (Binding.invoke t "resize" [| number cols; number rows |])
  end

  let exec ?cwd ?env ?user ?stdin ?stdout ?stderr ?pty t cmd =
    let options =
      Binding.options
        (List.filter_map Fun.id
           [
             field "cwd" str cwd;
             field "env" string_map env;
             field "user" str user;
             field "stdin"
               (function `Pipe -> str "pipe" | `Stream s -> Stream.to_js s)
               stdin;
             field "stdout"
               (function `Pipe -> str "pipe" | `Ignore -> str "ignore")
               stdout;
             field "stderr"
               (function
                 | `Pipe -> str "pipe"
                 | `Ignore -> str "ignore"
                 | `Combined -> str "combined")
               stderr;
             field "pty"
               (function
                 | `Default -> bool_js true
                 | `Size (cols, rows) ->
                     Js.Unsafe.inject
                       (Binding.options
                          [ ("cols", number cols); ("rows", number rows) ]))
               pty;
           ])
    in
    Binding.call ~decode:Fun.id t "exec"
      [| strings cmd; Js.Unsafe.inject options |]

  let of_js (v : js) : t = v
  let to_js (t : t) : js = t
end

module State = struct
  type t = js

  let id t = Id.of_js (Js.Unsafe.get t "id")
  let storage t = Storage.of_js (Js.Unsafe.get t "storage")
  let wait_until t f = Context.wait_until (Context.of_js t) f

  let container t =
    let c = Js.Unsafe.get t "container" in
    if is_nullish c then None else Some (Container.of_js c)

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

  let accept_websocket ?(tags = []) t ws =
    ignore
      (Binding.invoke t "acceptWebSocket"
         [|
           Websocket.to_js ws;
           Js.Unsafe.inject (Js.array (Array.of_list (List.map Js.string tags)));
         |])

  let websockets ?tag t =
    let args = match tag with None -> [||] | Some tag -> [| str tag |] in
    Decode.(list (fun ws -> Websocket.of_js ws))
      (Binding.invoke t "getWebSockets" args)

  let tags t ws =
    Decode.(list string) (Binding.invoke t "getTags" [| Websocket.to_js ws |])

  let set_websocket_auto_response t ~request ~response =
    let pair =
      Js.Unsafe.new_obj
        (global "WebSocketRequestResponsePair")
        [| str request; str response |]
    in
    ignore (Binding.invoke t "setWebSocketAutoResponse" [| pair |])

  let of_js (v : js) : t = v
  let to_js (t : t) : js = t
end

type alarm_info = { retry_count : int; is_retry : bool }

type t = {
  init : (unit -> unit) option;
  fetch : (Request.t -> Response.t) option;
  alarm : (alarm_info -> unit) option;
  websocket_message : (Websocket.t -> Websocket.message -> unit) option;
  websocket_close :
    (Websocket.t -> code:int -> reason:string -> was_clean:bool -> unit) option;
  websocket_error : (Websocket.t -> string -> unit) option;
  rpc : (string -> Rpc.t list -> Rpc.t) option;
}

let make ?init ?fetch ?alarm ?websocket_message ?websocket_close
    ?websocket_error ?rpc () =
  {
    init;
    fetch;
    alarm;
    websocket_message;
    websocket_close;
    websocket_error;
    rpc;
  }

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
      field "webSocketMessage"
        (Option.map
           (fun handler ws message : js ->
             Async.run (fun () ->
                 flushing (fun () ->
                     let message =
                       if typeof message = "string" then
                         Websocket.Text (Decode.string message)
                       else Websocket.Binary (Decode.bytes message)
                     in
                     handler (Websocket.of_js ws) message;
                     undefined)))
           t.websocket_message);
      field "webSocketClose"
        (Option.map
           (fun handler ws code reason was_clean : js ->
             Async.run (fun () ->
                 flushing (fun () ->
                     handler (Websocket.of_js ws) ~code:(int_of_js code)
                       ~reason:(Decode.string reason)
                       ~was_clean:(Decode.bool was_clean);
                     undefined)))
           t.websocket_close);
      field "webSocketError"
        (Option.map
           (fun handler ws error : js ->
             Async.run (fun () ->
                 flushing (fun () ->
                     let message =
                       Option.value
                         (get_string error "message")
                         ~default:
                           (Js.to_string (call (global "String") [| error |]))
                     in
                     handler (Websocket.of_js ws) message;
                     undefined)))
           t.websocket_error);
      field "rpc"
        (Option.map
           (fun rpc name args : js ->
             Async.run (fun () ->
                 flushing (fun () ->
                     let args = List.map Rpc.of_js (Decode.(list js) args) in
                     Rpc.to_js (rpc (Decode.string name) args))))
           t.rpc);
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

let rpc_reserved =
  [
    "fetch";
    "alarm";
    "connect";
    "constructor";
    "prototype";
    "webSocketMessage";
    "webSocketClose";
    "webSocketError";
  ]

let classes () =
  let root = Registry.root () in
  if typeof (Js.Unsafe.get root "durable_objects") = "undefined" then
    Js.Unsafe.set root "durable_objects" (Js.Unsafe.obj [||]);
  Js.Unsafe.get root "durable_objects"

let register ?(rpc = []) name create =
  let who = "Workero.Durable_object.register" in
  if not (is_class_name name) then
    invalid_arg (Printf.sprintf "%s: %S is not a valid class name" who name);
  List.iteri
    (fun i m ->
      if (not (is_class_name m)) || List.mem m rpc_reserved then
        invalid_arg
          (Printf.sprintf "%s: %S is not a valid RPC method name" who m);
      if List.exists (( = ) m) (List.filteri (fun j _ -> j < i) rpc) then
        invalid_arg
          (Printf.sprintf "%s: RPC method %S is declared twice in class %S" who
             m name))
    rpc;
  let classes = classes () in
  let root = Registry.root () in
  let taken table =
    let t = Js.Unsafe.get root table in
    typeof t <> "undefined" && has_own t name
  in
  if has_own classes name || taken "entrypoints" || taken "workflows" then
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
  let factory = Js.Unsafe.inject (Js.wrap_callback factory) in
  Js.Unsafe.set factory "rpc"
    (Js.Unsafe.inject (Js.array (Array.of_list (List.map Js.string rpc))));
  Js.Unsafe.set classes name factory

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

let call = Rpc.call
