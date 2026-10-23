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
module Status = Status
module Env = Env
module Context = Context
module Router = Router
module Scheduled = Scheduled
module Email = Email
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
module Hyperdrive = Hyperdrive
module Fetcher = Fetcher
module Abort_signal = Abort_signal
module Abort_controller = Abort_controller
module Queue = Queue
module Trace = Trace
module Socket = Socket
module Rate_limiter = Rate_limiter
module Ai = Ai
module Analytics_engine = Analytics_engine
module Rpc = Rpc
module Durable_object = Durable_object
module Entrypoint = Entrypoint
module Workflow = Workflow
module Html_rewriter = Html_rewriter

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

val queue : (Queue.Batch.t -> Env.t -> Context.t -> unit) -> unit
(** [queue handler] registers the queue consumer, like [queue(batch, env, ctx)]
    in a JavaScript Worker. It runs in a fiber and may call {!Promise.await},
    {!fetch} and the body readers. It can be combined with {!serve} and
    {!scheduled}. An exception raised by the handler rejects the event Promise,
    so the runtime retries the messages that the handler did not ack. *)

val email : (Email.t -> Env.t -> Context.t -> unit) -> unit
(** [email handler] registers the Email Routing handler, like
    [email(message, env, ctx)] in a JavaScript Worker. It runs in a fiber and
    may call {!Promise.await}, {!fetch} and the body readers. It can be combined
    with {!serve}, {!scheduled} and {!queue}. The handler must call
    {!Email.forward}, {!Email.reply} or {!Email.set_reject}, or the runtime
    drops the message. An exception raised by the handler rejects the event
    Promise, so the runtime treats the delivery as failed. *)

val tail : (Trace.t list -> Env.t -> Context.t -> unit) -> unit
(** [tail handler] registers the tail handler, like [tail(events, env, ctx)] in
    a JavaScript Worker. It receives the trace items of the producer Workers
    that list this Worker in [tail_consumers]. It runs in a fiber and may call
    {!Promise.await}, {!fetch} and the body readers; {!Context.wait_until} runs
    work after the handler returns. An exception raised by the handler rejects
    the event Promise. The runtime ignores a tail failure for the producer, so
    log inside the handler. Build a tail Worker as its own program, and do not
    list a Worker as its own tail consumer. *)

val fetch :
  ?signal:Abort_signal.t ->
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

    [signal] cancels the request and the reading of its body. When it aborts,
    the call or the body reader raises {!Js_error} with an [AbortError] or
    [TimeoutError]; see {!Abort_signal.is_abort}. A signal that has already
    aborted fails the call without a request. For a timeout, pass
    [~signal:(Abort_signal.timeout ms)].

    Raises [Invalid_argument] when [body] is given with [GET] or [HEAD].
    @raise Js_error when the request fails, for example on a network error. *)
