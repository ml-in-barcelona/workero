module Js = Js_of_ocaml.Js
open Internal

let flushing f = Fun.protect ~finally:flush_all f

let reserved =
  [
    "constructor";
    "prototype";
    "__proto__";
    "then";
    "env";
    "ctx";
    "fetch";
    "scheduled";
    "queue";
    "email";
    "tail";
    "trace";
    "tailStream";
    "test";
    "connect";
    "dup";
  ]

let throw message =
  Js.Js_error.raise_
    (Js.Js_error.of_error
       (Js.Unsafe.coerce (Js.Unsafe.new_obj (global "Error") [| str message |])))

let is_method_name name = is_identifier name && not (List.mem name reserved)

type t = {
  fetch : (Request.t -> Response.t) option;
  rpc : (string -> Rpc.t list -> Rpc.t) option;
  scheduled : (Scheduled.t -> unit) option;
  queue : (Queue.Batch.t -> unit) option;
  tail : (Trace.t list -> unit) option;
}

let make ?fetch ?rpc ?scheduled ?queue ?tail () =
  { fetch; rpc; scheduled; queue; tail }

let event_handler of_js handler =
 fun event : js ->
  Async.run (fun () ->
      flushing (fun () ->
          handler (of_js event);
          Js.Unsafe.inject Js.undefined))

let handlers_js t =
  let field name f = Option.map (fun f -> (name, Async.promising (f : _))) f in
  let fields =
    [
      field "fetch"
        (Option.map
           (fun fetch request : js ->
             Async.run (fun () ->
                 flushing (fun () ->
                     Response.to_js (fetch (Request.of_js request)))))
           t.fetch);
      field "rpc"
        (Option.map
           (fun rpc name args : js ->
             Async.run (fun () ->
                 flushing (fun () ->
                     let args = List.map Rpc.of_js (Decode.(list js) args) in
                     Rpc.to_js (rpc (Decode.string name) args))))
           t.rpc);
      field "scheduled" (Option.map (event_handler Scheduled.of_js) t.scheduled);
      field "queue" (Option.map (event_handler Queue.Batch.of_js) t.queue);
      field "tail"
        (Option.map
           (event_handler (fun events ->
                List.map Trace.of_js (Decode.(list js) events)))
           t.tail);
    ]
  in
  Js.Unsafe.obj (Array.of_list (List.filter_map Fun.id fields))

let classes () =
  let root = Registry.root () in
  if typeof (Js.Unsafe.get root "entrypoints") = "undefined" then
    Js.Unsafe.set root "entrypoints" (Js.Unsafe.obj [||]);
  Js.Unsafe.get root "entrypoints"

let register ?(rpc = []) name create =
  let who = "Workero.Entrypoint.register" in
  if not (is_class_name name) then
    invalid_arg (Printf.sprintf "%s: %S is not a valid class name" who name);
  (match List.find_opt (fun m -> not (is_method_name m)) rpc with
  | Some m ->
      invalid_arg (Printf.sprintf "%s: %S is not a valid method name" who m)
  | None -> ());
  if List.length (List.sort_uniq compare rpc) <> List.length rpc then
    invalid_arg (Printf.sprintf "%s: class %S repeats a method name" who name);
  let root = Registry.root () in
  let taken table =
    let t = Js.Unsafe.get root table in
    typeof t <> "undefined" && has_own t name
  in
  if taken "durable_objects" || taken "workflows" || has_own (classes ()) name
  then
    invalid_arg (Printf.sprintf "%s: class %S is already registered" who name);
  let create_js env ctx : js =
    match
      Async.no_await ~who:(who ^ " create function") (fun () ->
          handlers_js (create (Env.of_js env) (Context.of_js ctx)))
    with
    | handlers -> handlers
    | exception e ->
        throw
          (Printf.sprintf "workero: creating entrypoint %s failed: %s" name
             (Printexc.to_string e))
  in
  let factory = Js.Unsafe.inject (Js.wrap_callback create_js) in
  Js.Unsafe.set factory "rpc"
    (Js.Unsafe.inject (Js.array (Array.of_list (List.map str rpc))));
  Js.Unsafe.set (classes ()) name factory

let call = Rpc.call
