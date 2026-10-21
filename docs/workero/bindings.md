
# Bindings

Bindings give a Worker access to values and Cloudflare resources through its `env` argument. Configure variables and resources in `wrangler.toml`, and set secrets with Wrangler. Use [`Workero.Env.var`](https://ml-in-barcelona.github.io/workero/workero/Workero/Env/index.html#val-var) to read a string variable or secret. Use the resource's `of_env` function to read a resource binding.


## Choose an API

- [Variables and secrets](./env.md): read string configuration with [`Workero.Env.var`](https://ml-in-barcelona.github.io/workero/workero/Workero/Env/index.html#val-var).
- [KV](./kv.md): store text by key with [`Workero.KV`](./Workero-KV.md).
- [R2](./r2.md): store buffered object bytes with [`Workero.R2`](./Workero-R2.md).
- [D1](./d1.md): run SQL with [`Workero.D1`](./Workero-D1.md) and [`Workero.Sql_value`](./Workero-Sql_value.md).
workero supports these bindings, not every binding type in the [Cloudflare bindings API](https://developers.cloudflare.com/workers/runtime-apis/bindings/). The [Cache API](./cache.md) is not a binding. [`Workero.Cache`](./Workero-Cache.md) uses the global `caches.default` runtime API; see [Runtime APIs](./runtime_apis.md).


## Declare resource names

For local development, Wrangler can create local resources from the binding names alone:

```toml
[[kv_namespaces]]
binding = "KV"

[[r2_buckets]]
binding = "BUCKET"

[[d1_databases]]
binding = "DB"
```
`npx wrangler dev` uses local storage by default. You do not need to create remote resources to test these bindings locally. For a deploy, either let [Wrangler provision resources](https://developers.cloudflare.com/workers/wrangler/configuration/#automatic-provisioning) from these names or create remote resources with an authenticated Wrangler and add their IDs or names to `wrangler.toml`. Each resource guide shows both paths.


## Read a binding in a handler

The handler receives `env`. [`Workero.Env.var`](https://ml-in-barcelona.github.io/workero/workero/Workero/Env/index.html#val-var) returns `Some value` only for a string variable or secret; a missing or non-string value returns `None`. `KV.of_env env "KV"`, `R2.of_env env "BUCKET"` and `D1.of_env env "DB"` look up resource objects. They raise `Invalid_argument` with the binding name when the name is missing, the value is not an object of the expected shape, or the object lacks a required method. `of_env` does not perform a storage request.

Storage operations suspend like [`Workero.Promise.await`](https://ml-in-barcelona.github.io/workero/workero/Workero/Promise/index.html#val-await), so call them in direct style inside the handler. Runtime errors raise [`Workero.Js_error`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#exception-Js_error); [`Workero.Promise.error_to_string`](https://ml-in-barcelona.github.io/workero/workero/Workero/Promise/index.html#val-error_to_string) formats the underlying JavaScript error.
