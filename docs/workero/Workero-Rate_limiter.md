
# Module `Workero.Rate_limiter`

A Workers Rate Limiting binding, declared in `wrangler.toml` with `[[ratelimits]]`. The limit and its period come from the binding, not from the code.

```ocaml
type t
```
```ocaml
val of_env : Env.t -> string -> t
```
`of_env env name` is the rate limiter bound as `name`.

Raises `Invalid_argument` when `env` has no binding `name`, or when the binding has no `limit` method.

```ocaml
val limit : t -> string -> bool
```
`limit limiter key` counts one request for `key` and is `true` when it is allowed, `false` when `key` is over the limit. Suspends like [`Promise.await`](./Workero-Promise.md#val-await). The count is per location and approximate.

raises [`Js_error`](./Workero.md#exception-Js_error) when the runtime fails.
```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```