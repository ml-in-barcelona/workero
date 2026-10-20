
# Module `Workero`

Write Cloudflare Workers in OCaml (via wasm\_of\_ocaml)

```ocaml
type js = Js_of_ocaml.Js.Unsafe.any
```
A raw JavaScript value.

```ocaml
exception Js_error of string
```
Raised by [`Promise.await`](./Workero-Promise.md#val-await) when the awaited JavaScript Promise rejects. The payload is the rejection reason converted with JavaScript `String`.

```ocaml
module Promise : sig ... end
```
A JavaScript `Promise`, bound directly.

```ocaml
module URL : sig ... end
```
An absolute `http` or `https` URL, parsed by `Js_of_ocaml.Url`. Paths and query arguments are percent-decoded. In a query, `+` decodes to a space, as in WHATWG `URLSearchParams`.

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
module Env : sig ... end
```
```ocaml
module Context : sig ... end
```
The `ctx` argument of a Worker handler.

```ocaml
module Scheduled : sig ... end
```
The `controller` argument of a Worker `scheduled` handler.

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

raises `Invalid_argument` when body is given with GET or HEAD.
raises [`Js_error`](./#exception-Js_error) when the request fails, for example on a network error.