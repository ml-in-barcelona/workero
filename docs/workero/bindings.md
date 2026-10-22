
# Bindings

Bindings expose configuration and Cloudflare resources through the handler's `env` argument. Configure variables and resources in `wrangler.toml`, and set Worker secrets with Wrangler. Resource modules provide `of_env` functions to look up bindings and check their methods.


## What workero supports

- [Variables and secrets](./env.md): [`Workero.Env.var`](./Workero-Env.md#val-var) reads string variables and Worker secrets, [`Workero.Env.secret`](./Workero-Env.md#val-secret) requires a string, and [`Workero.Env.json`](./Workero-Env.md#val-json) reads object or array variables. These are values in `env`, not resource bindings.
- [Secrets Store](./env.md): [`Workero.Secret_store.of_env`](./Workero-Secret_store.md#val-of_env) looks up an account secret binding; [`Workero.Secret_store.get`](./Workero-Secret_store.md#val-get) reads its value.
- [KV](./kv.md): [`Workero.KV.of_env`](./Workero-KV.md#val-of_env) looks up a Workers KV namespace.
- [R2](./r2.md): [`Workero.R2.of_env`](./Workero-R2.md#val-of_env) looks up an object storage bucket.
- [D1](./d1.md): [`Workero.D1.of_env`](./Workero-D1.md#val-of_env) looks up a SQL database; use [`Workero.Sql_value`](./Workero-Sql_value.md) for SQL values.
- [Durable Objects](./durable_objects.md): [`Workero.Durable_object.Namespace.of_env`](./Workero-Durable_object-Namespace.md#val-of_env) looks up a namespace. Object classes support key-value and SQL storage, alarms, and hibernating WebSockets.
- [Service bindings and static assets](./fetcher.md): [`Workero.Fetcher.of_env`](./Workero-Fetcher.md#val-of_env) looks up either fetch-capable binding. Durable Object stubs from [`Workero.Durable_object.Namespace.get`](./Workero-Durable_object-Namespace.md#val-get) are also fetchers.
- [Queues](./queue.md): [`Workero.Queue.of_env`](./Workero-Queue.md#val-of_env) looks up a producer; the [`Workero.queue`](./Workero.md#val-queue) handler receives consumer batches, not an `of_env` binding.
- [Hyperdrive](./hyperdrive.md): [`Workero.Hyperdrive.of_env`](./Workero-Hyperdrive.md#val-of_env) looks up a database binding and reads its connection details; there is no query driver yet.
- [Rate Limiting](./rate_limiter.md): [`Workero.Rate_limiter.of_env`](./Workero-Rate_limiter.md#val-of_env) looks up a limiter.
- [Workers AI](./ai.md): [`Workero.Ai.of_env`](./Workero-Ai.md#val-of_env) looks up a model binding.
- [Workflows](./workflows.md): [`Workero.Workflow.of_env`](./Workero-Workflow.md#val-of_env) looks up a Workflow binding; [`Workero.Workflow.create`](./Workero-Workflow.md#val-create) starts an instance.
- [Analytics Engine](./analytics_engine.md): [`Workero.Analytics_engine.of_env`](./Workero-Analytics_engine.md#val-of_env) looks up a dataset.
[Cache](./cache.md) uses the runtime global `caches.default`, not `env` or an `of_env` binding. It needs no `wrangler.toml` entry.


## Declare a binding

Each resource has its own `wrangler.toml` entry. Most use `binding` as the name you pass to `of_env`; Rate Limiting uses `name`. For example:

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

[[services]]
binding = "BACKEND"
service = "backend-worker"

[[queues.producers]]
binding = "JOBS"
queue = "jobs"
```
See each binding page for its other settings and deployment steps.


## Use a binding

Call the module's `of_env env name` inside the handler. It raises `Invalid_argument` if the name is absent or the value does not have the expected methods. The error names the binding.

The lookup itself does not perform I/O. Operations that wait for a runtime result suspend like [`Workero.Promise.await`](./Workero-Promise.md#val-await); call them in direct style inside a handler. [`Workero.Analytics_engine.write`](./Workero-Analytics_engine.md#val-write) is synchronous and returns `unit`. A runtime failure raises [`Workero.Js_error`](./Workero.md#exception-Js_error); use [`Workero.Promise.error_to_string`](./Workero-Promise.md#val-error_to_string) to read the error name and message. Each binding page describes its own return values and limits.


## Develop locally

`wrangler dev` uses local resources by default for KV, R2, D1, Durable Objects, Queues, assets, Analytics Engine, Rate Limiting, and Secrets Store. Service bindings need the target Worker running with the caller. Workers AI always calls Cloudflare remotely and may incur usage charges. Local simulation does not prove remote writes or model results. See [Cloudflare's local binding support table](https://developers.cloudflare.com/workers/local-development/bindings-per-env/).

To deploy KV, R2 or D1, create the remote resources first:

```sh
npx wrangler kv namespace create KV
npx wrangler r2 bucket create my-bucket
npx wrangler d1 create my-database
```
Copy the identifiers into `wrangler.toml`. Do not run these creation commands for local development. See the binding pages for their examples and checks.
