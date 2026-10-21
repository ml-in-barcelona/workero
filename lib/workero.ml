module Js = Js_of_ocaml.Js
open Internal

type js = Internal.js

exception Js_error = Internal.Js_error

module Promise = Promise
module URL = Url
module Method = Method
module Cf = Cf
module Request = Request
module Response = Response
module Env = Env
module Context = Context
module Scheduled = Scheduled
module JSON = Json
module KV = Kv
module Cache = Cache
module R2 = R2
module D1 = D1
module Sql_value = Sql_value

let register name handler =
  let g = Js.Unsafe.global in
  if typeof (Js.Unsafe.get g "__workero") = "undefined" then
    Js.Unsafe.set g "__workero" (Js.Unsafe.obj [||]);
  Js.Unsafe.set (Js.Unsafe.get g "__workero") name (Async.promising handler)

let serve handler =
  register "fetch" (fun request env ctx : js ->
      Async.run (fun () ->
          Response.to_js
            (handler (Request.of_js request) (Env.of_js env) (Context.of_js ctx))))

let scheduled handler =
  register "scheduled" (fun controller env ctx : js ->
      Async.run (fun () ->
          handler
            (Scheduled.of_js controller)
            (Env.of_js env) (Context.of_js ctx);
          Js.Unsafe.inject Js.undefined))

let fetch ?(method_ = Method.GET) ?(headers = []) ?body url =
  (match (method_, body) with
  | (Method.GET | HEAD), Some _ ->
      invalid_arg "Workero.fetch: a GET or HEAD request has no body"
  | _ -> ());
  let fields =
    [
      ("method", str (Method.to_string method_));
      ("headers", Message.headers_of_list headers);
    ]
    @
    match body with
    | Some b -> [ ("body", Message.body_of_string b) ]
    | None -> []
  in
  let init = Js.Unsafe.obj (Array.of_list fields) in
  let p : js Promise.t =
    Promise.of_js (meth Js.Unsafe.global "fetch" [| str url; init |])
  in
  Response.of_js (Promise.await p)
