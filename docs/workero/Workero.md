
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
The `env` argument of a Worker handler: its variables, secrets and bindings.

```ocaml
module Context : sig ... end
```
The `ctx` argument of a Worker handler.

```ocaml
module Router : sig ... end
```
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
A Workers KV namespace, bound in `wrangler.toml` with `[[kv_namespaces]]`. Each function suspends like [`Promise.await`](./Workero-Promise.md#val-await) and raises [`Js_error`](./#exception-Js_error) when the runtime rejects.

```ocaml
module Cache : sig ... end
```
The Cache API of the data center that runs the Worker (`caches.default`). Entries are keyed by URL, and each data center has its own cache. Each function suspends like [`Promise.await`](./Workero-Promise.md#val-await) and raises [`Js_error`](./#exception-Js_error) when the runtime rejects.

```ocaml
module R2 : sig ... end
```
A Cloudflare R2 bucket, bound in `wrangler.toml` with `[[r2_buckets]]`. Each function suspends like [`Promise.await`](./Workero-Promise.md#val-await) and raises [`Js_error`](./#exception-Js_error) when the runtime rejects. Objects are raw bytes held in OCaml strings.

```ocaml
module D1 : sig ... end
```
A Cloudflare D1 database, bound in `wrangler.toml` with `[[d1_databases]]`. Each function suspends like [`Promise.await`](./Workero-Promise.md#val-await) and raises [`Js_error`](./#exception-Js_error) when the runtime rejects, for example on an SQL error.

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
The Web Crypto random functions of the global `crypto` object.

```ocaml
module Console : sig ... end
```
The global `console`. Each call writes one entry to the Workers logs, with its level. Unlike `print_string`, it needs no flush.

```ocaml
module Secret_store : sig ... end
```
A secret of Cloudflare Secrets Store, bound in `wrangler.toml` with `[[secrets_store_secrets]]`. The value is plain text: do not log it. For a secret set with `wrangler secret put`, use [`Env.secret`](./Workero-Env.md#val-secret).

```ocaml
module Fetcher : sig ... end
```
A `Fetcher` sends requests to another Worker, to static assets or to a Durable Object. Bind it in `wrangler.toml` with `[[services]]` or `[assets]`. The calls suspend like [`Promise.await`](./Workero-Promise.md#val-await). They raise [`Js_error`](./#exception-Js_error) when the runtime throws or rejects, for example when the target Worker raises.

```ocaml
module Queue : sig ... end
```
Cloudflare Queues. A [`t`](./Workero-Queue.md#type-t) sends messages to a queue, bound in `wrangler.toml` with `[[queues.producers]]`. A Worker reads messages with the handler that [`Workero.queue`](./#val-queue) registers.

```ocaml
module Rate_limiter : sig ... end
```
A Workers Rate Limiting binding, declared in `wrangler.toml` with `[[ratelimits]]`. The limit and its period come from the binding, not from the code.

```ocaml
module Ai : sig ... end
```
A Workers AI binding, declared in `wrangler.toml` with `[ai]`. Workers AI runs models and bills your account, also in `wrangler dev`.

```ocaml
module Analytics_engine : sig ... end
```
A Workers Analytics Engine dataset, declared in `wrangler.toml` with `[[analytics_engine_datasets]]`.

```ocaml
module Durable_object : sig ... end
```
Durable Objects with SQLite storage.

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
val fetch : 
  ?method_:Method.t ->
  ?headers:(string * string) list ->
  ?body:string ->
  string ->
  Response.t
```
`fetch url` sends an HTTP request and waits for the response headers, like JavaScript `fetch`. `method_` is `GET` by default. `body` is sent as raw bytes and sets no `content-type`. Read the response body with [`Response.body_text`](./Workero-Response.md#val-body_text) or [`Response.body_bytes`](./Workero-Response.md#val-body_bytes). Call it only from inside a handler or a [`Context.wait_until`](./Workero-Context.md#val-wait_until) function.

Raises `Invalid_argument` when `body` is given with `GET` or `HEAD`.

raises [`Js_error`](./#exception-Js_error) when the request fails, for example on a network error.