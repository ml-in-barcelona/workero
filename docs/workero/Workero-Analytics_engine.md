
# Module `Workero.Analytics_engine`

A Workers Analytics Engine dataset, declared in `wrangler.toml` with `[[analytics_engine_datasets]]`.

```ocaml
type t
```
```ocaml
type blob = 
  | Text of string
  | Bytes of string
```
A blob of a data point.

```ocaml
val of_env : Env.t -> string -> t
```
`of_env env name` is the dataset bound as `name`.

Raises `Invalid_argument` when `env` has no binding `name`, or when the binding has no `writeDataPoint` method.

```ocaml
val write : 
  ?index:string ->
  ?doubles:float list ->
  ?blobs:blob list ->
  t ->
  unit
```
`write dataset` submits one data point. `index` is the sampling key. The runtime accepts one index, up to 20 `doubles` and up to 20 `blobs`. This call does not wait for persistence and returns `unit` immediately.

raises [`Js_error`](./Workero.md#exception-Js_error) when the runtime throws during the call.
```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```