
# Module `Workero`

Write Cloudflare Workers in OCaml (via wasm\_of\_ocaml)

```ocaml
type js_value = Js_of_ocaml.Js.Unsafe.any
```
An unchecked JavaScript value: what `of_js` takes and `to_js` returns. Read it with [`Decode`](./Workero-Decode.md).

```ocaml
exception Js_error of Promise.error
```
Raised by [`Promise.await`](./Workero-Promise.md#val-await) when the awaited JavaScript Promise rejects, and by the bindings when the runtime throws. The payload is the original rejection reason; [`Promise.error_to_string`](./Workero-Promise.md#val-error_to_string) shows it as JavaScript `String` does, for example `"TypeError: bad argument"`.

```ocaml
module Promise : sig ... end
```
A JavaScript `Promise` of an OCaml value.

```ocaml
module Decode : sig ... end
```
Decoders for raw JavaScript values, for [`Promise.of_js`](./Workero-Promise.md#val-of_js). A decoder raises `Invalid_argument` naming the expected and the actual JavaScript type.

```ocaml
module URL : sig ... end
```
An absolute `http` or `https` URL, parsed by the JavaScript `URL`. Paths and query arguments are percent-decoded. In a query, `+` decodes to a space, as in WHATWG `URLSearchParams`.

```ocaml
module Method : sig ... end
```
An HTTP request method.

```ocaml
module Cf : sig ... end
```
Cloudflare properties of an incoming request, from `request.cf`. Each accessor is `None` when the runtime does not provide the property, for example outside Cloudflare's network or in a local test.

```ocaml
module Request : sig ... end
```
```ocaml
module Response : sig ... end
```
```ocaml
module Status : sig ... end
```
HTTP status codes as polymorphic variants, with the names and groups of Dream. ``Status n` stands for any other code.

```ocaml
module Env : sig ... end
```
The `env` argument of a Worker handler: string and JSON-shaped variables, Worker secrets, and resource bindings. See [Variables and secrets](./env.md).

```ocaml
module Context : sig ... end
```
The `ctx` argument of a Worker handler.

```ocaml
module Router : sig ... end
```
Dispatch requests by method and decoded path. See [Router](./router.md) for a complete Worker and expected responses.

```ocaml
module Scheduled : sig ... end
```
The `controller` argument of a Worker `scheduled` handler.

```ocaml
module Email : sig ... end
```
Email Routing. The handler that [`Workero.email`](./#val-email) registers receives a [`t`](./Workero-Email.md#type-t): a message that Cloudflare Email Routing delivered to the Worker. The handler can read the message, forward it, reply to it or reject it.

```ocaml
module JSON : sig ... end
```
JSON requests and responses for workero (`Workero.JSON`).

```ocaml
module KV : sig ... end
```
Text values in a Workers KV namespace, bound with `[[kv_namespaces]]` in `wrangler.toml`. Storage operations suspend like [`Promise.await`](./Workero-Promise.md#val-await) and raise [`Js_error`](./#exception-Js_error) when the runtime rejects. KV is eventually consistent across locations; 60 seconds is not a guaranteed visibility bound.

```ocaml
module Cache : sig ... end
```
The global `caches.default` runtime API, not an `env` binding. Entries are keyed by URL string in the data center that runs the Worker. Operations suspend like [`Promise.await`](./Workero-Promise.md#val-await) and raise [`Js_error`](./#exception-Js_error) when the runtime rejects.

```ocaml
module R2 : sig ... end
```
Buffered object bytes in a Cloudflare R2 bucket, bound with `[[r2_buckets]]` in `wrangler.toml`. Storage operations suspend like [`Promise.await`](./Workero-Promise.md#val-await) and raise [`Js_error`](./#exception-Js_error) when the runtime rejects. Objects are raw bytes held in OCaml strings.

```ocaml
module D1 : sig ... end
```
Basic SQL queries on a Cloudflare D1 database, bound with `[[d1_databases]]` in `wrangler.toml`. Storage operations suspend like [`Promise.await`](./Workero-Promise.md#val-await) and raise [`Js_error`](./#exception-Js_error) when the runtime rejects, for example on an SQL error.

```ocaml
module Sql_value : sig ... end
```
A value of an SQL column, as sent to and received from a JavaScript SQL API such as D1.

```ocaml
module Stream : sig ... end
```
Byte streams: a JavaScript `ReadableStream` and its readers and writers.

```ocaml
module Form_data : sig ... end
```
Parsed `multipart/form-data` and `application/x-www-form-urlencoded` bodies: a JavaScript `FormData`. Get one from [`Request.form_data`](./Workero-Request.md#val-form_data).

```ocaml
module Websocket : sig ... end
```
WebSockets served by the Worker, read by pulling events with [`receive`](./Workero-Websocket.md#val-receive).

```ocaml
module Timer : sig ... end
```
JavaScript timers: `setTimeout`, `setInterval` and their `clear` functions. Delays are in milliseconds. Call them only from inside a handler or a [`Context.wait_until`](./Workero-Context.md#val-wait_until) function; the Workers runtime refuses timers at startup.

```ocaml
module Date : sig ... end
```
JavaScript `Date`. Times are milliseconds since the Unix epoch, as a `float`. In Workers, the clock advances only after I/O, so it does not measure CPU time.

```ocaml
module Crypto : sig ... end
```
The Web Crypto functions of the global `crypto` object: random values and `crypto.subtle`. See [Timers, time, and randomness](./globals.md) and [Web Crypto](./crypto.md).

```ocaml
module Console : sig ... end
```
The global `console`. Each call writes one entry to the Workers logs, with its level. Unlike `print_string`, it needs no flush.

```ocaml
module Secret_store : sig ... end
```
A secret of Cloudflare Secrets Store, bound in `wrangler.toml` with `[[secrets_store_secrets]]`. Local `wrangler dev` requires a local Secrets Store secret; it cannot read the remote one. The value is plain text: do not log it. For a Worker secret set with `wrangler secret put`, use [`Env.secret`](./Workero-Env.md#val-secret).

```ocaml
module Hyperdrive : sig ... end
```
A Hyperdrive binding, declared in `wrangler.toml` with `[[hyperdrive]]`. Hyperdrive pools and caches connections to a PostgreSQL or MySQL database.

```ocaml
module Fetcher : sig ... end
```
A `Fetcher` sends requests to another Worker, to static assets or to a Durable Object. Configure service and assets bindings in `wrangler.toml` with `[[services]]` or `[assets]`. A Durable Object stub comes from [`Durable_object.Namespace.get`](./Workero-Durable_object-Namespace.md#val-get). The calls suspend like [`Promise.await`](./Workero-Promise.md#val-await). They raise [`Js_error`](./#exception-Js_error) when the runtime throws or rejects, for example when the target Worker raises.

```ocaml
module Abort_signal : sig ... end
```
`AbortSignal`: tells running work to stop.

```ocaml
module Abort_controller : sig ... end
```
`AbortController`: aborts an [`Abort_signal`](./Workero-Abort_signal.md).

```ocaml
module Queue : sig ... end
```
Cloudflare Queues. A [`t`](./Workero-Queue.md#type-t) sends messages through a producer binding in `wrangler.toml` (`[[queues.producers]]`). A [`Workero.queue`](./#val-queue) handler consumes batches from a queue configured under `[[queues.consumers]]`, not through a producer binding. See [Queue](./queue.md) for a complete Worker.

```ocaml
module Trace : sig ... end
```
Trace items, the argument of a [`Workero.tail`](./#val-tail) handler. A trace item records one invocation of a producer Worker: its event, its console output, its exceptions and its outcome. See [Tail Workers](./tail.md).

```ocaml
module Socket : sig ... end
```
Outbound TCP sockets, like `connect` from `cloudflare:sockets`. `index.js` imports `connect` on every build, so a program needs no setup. See [Sockets](./socket.md).

```ocaml
module Rate_limiter : sig ... end
```
A Workers Rate Limiting binding, declared in `wrangler.toml` with `[[ratelimits]]`. The binding's `name` is passed to [`of_env`](./Workero-Rate_limiter.md#val-of_env); the limit and its period come from the binding, not from the code.

```ocaml
module Ai : sig ... end
```
A Workers AI binding, declared in `wrangler.toml` with `[ai]`. Models run remotely, including under `wrangler dev`, and consume account usage.

```ocaml
module Analytics_engine : sig ... end
```
A Workers Analytics Engine dataset, declared in `wrangler.toml` with `[[analytics_engine_datasets]]`.

```ocaml
module Rpc : sig ... end
```
Values of Workers RPC calls.

```ocaml
module Durable_object : sig ... end
```
Durable Objects with SQLite-backed key-value and SQL storage.

```ocaml
module Entrypoint : sig ... end
```
`WorkerEntrypoint` classes with RPC methods.

```ocaml
module Workflow : sig ... end
```
Cloudflare Workflows: durable, multi-step programs.

```ocaml
module Html_rewriter : sig ... end
```
Rewrite an HTML response while it streams, like the JavaScript `HTMLRewriter`. The runtime parses the body and calls your functions for the nodes that match. OCaml does not read the body, so a large page costs no OCaml memory except the nodes that you handle.

```ocaml
val serve : (Request.t -> Env.t -> Context.t -> Response.t) -> unit
```
`serve handler` registers the request handler, like `fetch(request, env, ctx)` in a JavaScript Worker. The handler runs in a fiber and may call [`Promise.await`](./Workero-Promise.md#val-await), [`fetch`](./#val-fetch) and the body readers. An exception raised by the handler rejects the response Promise, and the runtime answers with status 500\.

```ocaml
val scheduled : (Scheduled.t -> Env.t -> Context.t -> unit) -> unit
```
`scheduled handler` registers the cron trigger handler, like `scheduled(controller, env, ctx)` in a JavaScript Worker. It runs in a fiber and may call [`Promise.await`](./Workero-Promise.md#val-await), [`fetch`](./#val-fetch) and the body readers. It can be combined with [`serve`](./#val-serve); a Worker may register either or both. An exception raised by the handler rejects the event Promise, so Cloudflare records the run as failed.

```ocaml
val queue : (Queue.Batch.t -> Env.t -> Context.t -> unit) -> unit
```
`queue handler` registers the queue consumer, like `queue(batch, env, ctx)` in a JavaScript Worker. It runs in a fiber and may call [`Promise.await`](./Workero-Promise.md#val-await), [`fetch`](./#val-fetch) and the body readers. It can be combined with [`serve`](./#val-serve) and [`scheduled`](./#val-scheduled). An exception raised by the handler rejects the event Promise, so the runtime retries the messages that the handler did not ack.

```ocaml
val email : (Email.t -> Env.t -> Context.t -> unit) -> unit
```
`email handler` registers the Email Routing handler, like `email(message, env, ctx)` in a JavaScript Worker. It runs in a fiber and may call [`Promise.await`](./Workero-Promise.md#val-await), [`fetch`](./#val-fetch) and the body readers. It can be combined with [`serve`](./#val-serve), [`scheduled`](./#val-scheduled) and [`queue`](./#val-queue). The handler must call [`Email.forward`](./Workero-Email.md#val-forward), [`Email.reply`](./Workero-Email.md#val-reply) or [`Email.set_reject`](./Workero-Email.md#val-set_reject), or the runtime drops the message. An exception raised by the handler rejects the event Promise, so the runtime treats the delivery as failed.

```ocaml
val tail : (Trace.t list -> Env.t -> Context.t -> unit) -> unit
```
`tail handler` registers the tail handler, like `tail(events, env, ctx)` in a JavaScript Worker. It receives the trace items of the producer Workers that list this Worker in `tail_consumers`. It runs in a fiber and may call [`Promise.await`](./Workero-Promise.md#val-await), [`fetch`](./#val-fetch) and the body readers; [`Context.wait_until`](./Workero-Context.md#val-wait_until) runs work after the handler returns. An exception raised by the handler rejects the event Promise. The runtime ignores a tail failure for the producer, so log inside the handler. Build a tail Worker as its own program, and do not list a Worker as its own tail consumer.

```ocaml
val tail_stream : 
  (Trace.Stream.t -> Env.t -> Context.t -> Trace.Stream.t -> unit) ->
  unit
```
`tail_stream handler` registers the streaming tail handler, like `tailStream(onset, env, ctx)` in a JavaScript Worker. The runtime calls `handler` once for each invocation of a producer Worker that lists this Worker in `streaming_tail_consumers`, with the onset event. `handler` returns the function that receives each later event of the same invocation, as it happens, up to the outcome. Both run in a fiber, like [`tail`](./#val-tail). Build a tail Worker as its own program.

```ocaml
val fetch : 
  ?signal:Abort_signal.t ->
  ?method_:Method.t ->
  ?headers:(string * string) list ->
  ?body:string ->
  string ->
  Response.t
```
`fetch url` sends an HTTP request and waits for the response headers, like JavaScript `fetch`. `method_` is `GET` by default. `body` is sent as raw bytes and sets no `content-type`. Read the response body with [`Response.body_text`](./Workero-Response.md#val-body_text) or [`Response.body_bytes`](./Workero-Response.md#val-body_bytes). Call it only from inside a handler or a [`Context.wait_until`](./Workero-Context.md#val-wait_until) function.

`signal` cancels the request and the reading of its body. When it aborts, the call or the body reader raises [`Js_error`](./#exception-Js_error) with an `AbortError` or `TimeoutError`; see [`Abort_signal.is_abort`](./Workero-Abort_signal.md#val-is_abort). A signal that has already aborted fails the call without a request. For a timeout, pass `~signal:(Abort_signal.timeout ms)`.

Raises `Invalid_argument` when `body` is given with `GET` or `HEAD`.

raises [`Js_error`](./#exception-Js_error) when the request fails, for example on a network error.