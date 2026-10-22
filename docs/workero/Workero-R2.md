
# Module `Workero.R2`

Buffered object bytes in a Cloudflare R2 bucket, bound with `[[r2_buckets]]` in `wrangler.toml`. Storage operations suspend like [`Promise.await`](./Workero-Promise.md#val-await) and raise [`Js_error`](./Workero.md#exception-Js_error) when the runtime rejects. Objects are raw bytes held in OCaml strings.

```ocaml
type t
```
```ocaml
val of_env : Env.t -> string -> t
```
`of_env env name` looks up the bucket bound as `name`. It does not suspend. Raises `Invalid_argument` if the binding is missing, is not an object, or lacks `get`, `put`, `head`, or `delete`. The error names the binding.

```ocaml
val get : t -> string -> string option
```
The entire body of an object as bytes, or `None` when the key does not exist. Reads the body into Worker memory.

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
The metadata of an object without its body, or `None` when the key does not exist. `head` and `get` are separate, non-atomic requests.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```