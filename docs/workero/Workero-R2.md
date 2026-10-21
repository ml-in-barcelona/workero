
# Module `Workero.R2`

A Cloudflare R2 bucket, bound in `wrangler.toml` with `[[r2_buckets]]`. Each function suspends like [`Promise.await`](./Workero-Promise.md#val-await) and raises [`Js_error`](./Workero.md#exception-Js_error) when the runtime rejects. Objects are raw bytes held in OCaml strings.

```ocaml
type t
```
```ocaml
val of_env : Env.t -> string -> t
```
`of_env env name` is the bucket bound as `name`.

Raises `Invalid_argument` when `env` has no binding `name`.

```ocaml
val get : t -> string -> string option
```
The bytes of an object, or `None` when the key does not exist.

```ocaml
val put : ?content_type:string -> t -> string -> string -> unit
```
`put bucket key bytes` stores `bytes` under `key`, replacing any object. `content_type` is kept as the object's `Content-Type`.

```ocaml
val delete : t -> string -> unit
```
Deletes an object. It is not an error when the key does not exist.

```ocaml
type info = {
  size : int;
  etag : string;
  content_type : string option;
}
```
```ocaml
val head : t -> string -> info option
```
The metadata of an object without its body, or `None` when the key does not exist.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```