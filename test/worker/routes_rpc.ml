open Workero
module D = Durable_object

let target env = function
  | "do" ->
      Some
        (D.call
           (D.Namespace.get_by_name (D.Namespace.of_env env "RPC") "values"))
  | "entrypoint" -> Some (Entrypoint.call (Fetcher.of_env env "CALC"))
  | "js-entrypoint" -> Some (Entrypoint.call (Fetcher.of_env env "JSRPC"))
  | "js-do" ->
      Some
        (D.call
           (D.Namespace.get_by_name (D.Namespace.of_env env "JSDO") "values"))
  | _ -> None

let lines f =
  String.concat "\n" (List.map (fun (k, v) -> k ^ ": " ^ f v) Rpc_values.values)

let echo call =
  lines (fun v ->
      match call "same" [ v ] with
      | r when Rpc_values.show r = Rpc_values.show v -> "ok"
      | r ->
          Printf.sprintf "sent %s, got %s" (Rpc_values.show v)
            (Rpc_values.show r))

let kinds call =
  lines (fun v ->
      match call "kind" [ v ] with `String s -> s | r -> Rpc_values.show r)

let functions call =
  let double =
    `Function
      (function
      | [ `Int n ] -> `Int (n * 2)
      | _ -> invalid_arg "double: one int")
  in
  let applied = Rpc_values.show (call "call_fn" [ double; `Int 21 ]) in
  let returned =
    match call "make_fn" [] with
    | `Function f -> Rpc_values.show (f [ `Int 1 ])
    | r -> "not a function: " ^ Rpc_values.show r
  in
  Printf.sprintf "call_fn: %s\nmake_fn: %s" applied returned

let streams ctx call =
  let w, r = Stream.pipe () in
  Context.wait_until ctx (fun () ->
      Stream.Writer.write w "xyz";
      Stream.Writer.write w "123";
      Stream.Writer.close w);
  let sent = Rpc_values.show (call "stream_text" [ `Stream r ]) in
  let received =
    match call "make_stream" [] with
    | `Stream s -> Rpc_values.read_all s
    | r -> "not a stream: " ^ Rpc_values.show r
  in
  Printf.sprintf "stream_text: %s\nmake_stream: %S" sent received

let stubs env call =
  let text = function
    | `String s -> s
    | r -> "unexpected: " ^ Rpc_values.show r
  in
  let service = call "stub_text" [ `Stub (Fetcher.of_env env "CALC") ] in
  let object_stub =
    call "stub_text"
      [
        `Stub (D.Namespace.get_by_name (D.Namespace.of_env env "RPC") "values");
      ]
  in
  let given =
    match call "give_stub" [] with
    | `Stub s -> Response.body_text (Fetcher.fetch s "http://x/p")
    | r -> "not a stub: " ^ Rpc_values.show r
  in
  Printf.sprintf "service: %s\ndurable object: %s\ngive_stub: %s" (text service)
    (text object_stub) given

let handle req env ctx =
  match String.split_on_char '/' (URL.path (Request.url req)) with
  | [ ""; "rpc-values"; name; scenario ] -> (
      match target env name with
      | None -> None
      | Some call -> (
          let run =
            match scenario with
            | "echo" -> Some (fun () -> echo call)
            | "kinds" -> Some (fun () -> kinds call)
            | "functions" -> Some (fun () -> functions call)
            | "streams" -> Some (fun () -> streams ctx call)
            | "stubs" -> Some (fun () -> stubs env call)
            | _ -> None
          in
          match run with
          | None -> None
          | Some run -> (
              match run () with
              | body -> Some (Response.text body)
              | exception Js_error e ->
                  Some
                    (Response.text ~status:`Bad_Gateway
                       (Promise.error_to_string e)))))
  | _ -> None
