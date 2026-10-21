module Js = Js_of_ocaml.Js
open Internal

type js_value = Internal.js

exception Js_error = Promise.Js_error

module Promise = Promise
module Decode = Decode
module URL = Url
module Method = Method
module Cf = Cf
module Request = Request
module Response = Response
module Status = Status
module Env = Env
module Context = Context
module Scheduled = Scheduled
module JSON = Json
module KV = Kv
module Cache = Cache
module R2 = R2
module D1 = D1
module Sql_value = Sql_value
module Stream = Stream
module Form_data = Form_data
module Websocket = Websocket
module Timer = Timer
module Date = Date
module Crypto = Crypto
module Console = Console
module Secret_store = Secret_store
module Fetcher = Fetcher
module Queue = Queue
module Rate_limiter = Rate_limiter
module Ai = Ai
module Analytics_engine = Analytics_engine

let register name handler = Registry.set name (Async.promising handler)
let flushing f = Fun.protect ~finally:flush_all f

let serve handler =
  register "fetch" (fun request env ctx : js ->
      Async.run (fun () ->
          flushing (fun () ->
              Response.to_js
                (handler (Request.of_js request) (Env.of_js env)
                   (Context.of_js ctx)))))

let scheduled handler =
  register "scheduled" (fun controller env ctx : js ->
      Async.run (fun () ->
          flushing (fun () ->
              handler
                (Scheduled.of_js controller)
                (Env.of_js env) (Context.of_js ctx);
              Js.Unsafe.inject Js.undefined)))

let queue handler =
  register "queue" (fun batch env ctx : js ->
      Async.run (fun () ->
          flushing (fun () ->
              handler (Queue.Batch.of_js batch) (Env.of_js env)
                (Context.of_js ctx);
              Js.Unsafe.inject Js.undefined)))

let fetch ?method_ ?headers ?body url =
  let init = Wire.fetch_init ~who:"Workero.fetch" ?method_ ?headers ?body () in
  let p =
    Promise.of_js ~decode:Decode.js
      (meth Js.Unsafe.global "fetch" [| str url; init |])
  in
  Response.of_js (Promise.await p)
