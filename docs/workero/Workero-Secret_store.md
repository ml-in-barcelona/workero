
# Module `Workero.Secret_store`

A secret of Cloudflare Secrets Store, bound in `wrangler.toml` with `[[secrets_store_secrets]]`. Local `wrangler dev` requires a local Secrets Store secret; it cannot read the remote one. The value is plain text: do not log it. For a Worker secret set with `wrangler secret put`, use [`Env.secret`](./Workero-Env.md#val-secret).

```ocaml
type t
```
```ocaml
val of_env : Env.t -> string -> t
```
`of_env env name` is the secret bound as `name`.

Raises `Invalid_argument` when `env` has no binding `name`.

```ocaml
val get : t -> string option
```
The value of the secret, or `None` when the runtime returns `null` or `undefined`. Suspends like [`Promise.await`](./Workero-Promise.md#val-await). Raises [`Js_error`](./Workero.md#exception-Js_error) when access fails, for example when the secret does not exist or the Worker may not read the store.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```