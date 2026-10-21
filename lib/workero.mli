(** Write Cloudflare Workers in OCaml (via wasm_of_ocaml) *)

type js_value = Js_of_ocaml.Js.Unsafe.any
(** An unchecked JavaScript value: what [of_js] takes and [to_js] returns. Read
    it with {!Decode}. *)

exception Js_error of Promise.error
(** Raised by {!Promise.await} when the awaited JavaScript Promise rejects, and
    by the bindings when the runtime throws. The payload is the original
    rejection reason; {!Promise.error_to_string} shows it as JavaScript [String]
    does, for example ["TypeError: bad argument"]. *)

module Promise = Promise
module Decode = Decode
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

val serve : (Request.t -> Env.t -> Context.t -> Response.t) -> unit
(** [serve handler] registers the request handler, like
    [fetch(request, env, ctx)] in a JavaScript Worker. The handler runs in a
    fiber and may call {!Promise.await}, {!fetch} and the body readers. An
    exception raised by the handler rejects the response Promise, and the
    runtime answers with status 500. *)

val scheduled : (Scheduled.t -> Env.t -> Context.t -> unit) -> unit
(** [scheduled handler] registers the cron trigger handler, like
    [scheduled(controller, env, ctx)] in a JavaScript Worker. It runs in a fiber
    and may call {!Promise.await}, {!fetch} and the body readers. It can be
    combined with {!serve}; a Worker may register either or both. An exception
    raised by the handler rejects the event Promise, so Cloudflare records the
    run as failed. *)

val fetch :
  ?method_:Method.t ->
  ?headers:(string * string) list ->
  ?body:string ->
  string ->
  Response.t
(** [fetch url] sends an HTTP request and waits for the response headers, like
    JavaScript [fetch]. [method_] is [GET] by default. [body] is sent as raw
    bytes and sets no [content-type]. Read the response body with
    {!Response.body_text} or {!Response.body_bytes}. Call it only from inside a
    handler or a {!Context.wait_until} function.

    Raises [Invalid_argument] when [body] is given with [GET] or [HEAD].
    @raise Js_error when the request fails, for example on a network error. *)
