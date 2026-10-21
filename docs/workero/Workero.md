
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
module Scheduled : sig ... end
```
The `controller` argument of a Worker `scheduled` handler.

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
val serve : (Request.t -> Env.t -> Context.t -> Response.t) -> unit
```
`serve handler` registers the request handler, like `fetch(request, env, ctx)` in a JavaScript Worker. The handler runs in a fiber and may call [`Promise.await`](./Workero-Promise.md#val-await), [`fetch`](./#val-fetch) and the body readers. An exception raised by the handler rejects the response Promise, and the runtime answers with status 500\.

```ocaml
val scheduled : (Scheduled.t -> Env.t -> Context.t -> unit) -> unit
```
`scheduled handler` registers the cron trigger handler, like `scheduled(controller, env, ctx)` in a JavaScript Worker. It runs in a fiber and may call [`Promise.await`](./Workero-Promise.md#val-await), [`fetch`](./#val-fetch) and the body readers. It can be combined with [`serve`](./#val-serve); a Worker may register either or both. An exception raised by the handler rejects the event Promise, so Cloudflare records the run as failed.

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