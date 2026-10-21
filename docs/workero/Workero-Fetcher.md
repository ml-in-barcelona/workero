
# Module `Workero.Fetcher`

A `Fetcher` sends requests to another Worker, to static assets or to a Durable Object. Bind it in `wrangler.toml` with `[[services]]` or `[assets]`. The calls suspend like [`Promise.await`](./Workero-Promise.md#val-await). They raise [`Js_error`](./Workero.md#exception-Js_error) when the runtime throws or rejects, for example when the target Worker raises.

```ocaml
type t
```
```ocaml
val of_env : Env.t -> string -> t
```
`of_env env name` is the service or assets binding `name`.

Raises `Invalid_argument` when `env` has no binding `name`, or when the binding has no `fetch` method.

```ocaml
val fetch : 
  ?method_:Method.t ->
  ?headers:(string * string) list ->
  ?body:string ->
  t ->
  string ->
  Response.t
```
`fetch fetcher url` sends a request to the target and waits for the response headers. The rules are those of [`Workero.fetch`](./Workero.md#val-fetch): `method_` is `GET` by default and `body` is sent as raw bytes without a `content-type`.

The URL must be absolute. A service binding ignores the host, so any host works, such as `"http://service/path"`; the target sees the path and the query. An assets binding looks the path up in the asset directory.

Raises `Invalid_argument` when `body` is given with `GET` or `HEAD`.

```ocaml
val fetch_request : t -> Request.t -> Response.t
```
`fetch_request fetcher req` forwards `req` as it is, with its method, headers and body. `req` cannot be used after the call: the runtime consumes its body. Use [`Request.clone`](./Workero-Request.md#val-clone) first to keep a copy.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```