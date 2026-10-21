
# Bindings

A binding connects your Worker to a Cloudflare resource, such as a key-value namespace or a database. You declare it in `wrangler.toml`. At run time it is a name in `env`, and you open it with `of_env`.


## What workero supports

- [KV](./kv.md): [`Workero.KV`](./Workero-KV.md), Workers KV namespaces.
- [Cache](./cache.md): [`Workero.Cache`](./Workero-Cache.md), the Cache API.
- [R2](./r2.md): [`Workero.R2`](./Workero-R2.md), object storage.
- [D1](./d1.md): [`Workero.D1`](./Workero-D1.md) and [`Workero.Sql_value`](./Workero-Sql_value.md), SQL databases.
String variables and secrets are not bindings. [`Workero.Env.var`](./Workero-Env.md#val-var) reads them. See [Variables and secrets](./env.md).


## Declare a binding

Each resource has a table in `wrangler.toml`. `binding` is the name that you pass to `of_env`:

```toml
[[kv_namespaces]]
binding = "KV"
id = "<namespace id>"

[[r2_buckets]]
binding = "BUCKET"
bucket_name = "my-bucket"

[[d1_databases]]
binding = "DB"
database_name = "my-database"
database_id = "<database id>"
```
The Cache API has no binding. [`Workero.Cache`](./Workero-Cache.md) uses the cache of the data center that runs the Worker.


## Use a binding

`of_env env name` returns the binding. It raises `Invalid_argument` when `env` has no binding with that name. The message names it. Open the binding inside the handler, where you have `env`.

Every operation suspends like [`Workero.Promise.await`](./Workero-Promise.md#val-await), so you call it in direct style. When the runtime fails, for example on an SQL error or a network error, the operation raises [`Workero.Js_error`](./Workero.md#exception-Js_error). The payload is a [`Workero.Promise.error`](./Workero-Promise.md#type-error), the original JavaScript error. That includes errors that JavaScript throws before it returns a Promise. [`Workero.Promise.error_to_string`](./Workero-Promise.md#val-error_to_string) gives `"Name: message"`.


## Develop locally

`wrangler dev` runs bindings against local storage by default. KV, R2 and D1 need no Cloudflare account for this, and the data stays on your machine. Create the resources for a deploy with Wrangler:

```sh
npx wrangler kv namespace create KV
npx wrangler r2 bucket create my-bucket
npx wrangler d1 create my-database
```
Each command prints the values for `wrangler.toml`. Each binding page has a complete Worker.
