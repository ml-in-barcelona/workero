
# Analytics Engine

[`Workero.Analytics_engine`](./Workero-Analytics_engine.md) writes data points to a [Workers Analytics Engine](https://developers.cloudflare.com/analytics/analytics-engine/) dataset. You read deployed data through the [SQL API](https://developers.cloudflare.com/analytics/analytics-engine/sql-api/).


## Configure

```toml
[[analytics_engine_datasets]]
binding = "EVENTS"
dataset = "events"
```

## Use

```ocaml
let handler req env _ctx =
  let open Workero in
  let events = Analytics_engine.of_env env "EVENTS" in
  let path = URL.path (Request.url req) in
  Analytics_engine.write ~index:path ~doubles:[ 1. ]
    ~blobs:[ Text (Method.to_string (Request.method_ req)) ]
    events;
  Response.text "ok\n"

let () = Workero.serve handler
```
- [`Workero.Analytics_engine.of_env`](./Workero-Analytics_engine.md#val-of_env) opens the dataset. It raises `Invalid_argument` when there is no such binding, or when the binding has no `writeDataPoint` method.
- [`Workero.Analytics_engine.write`](./Workero-Analytics_engine.md#val-write) records one data point. `index` is the sampling key, `doubles` are the numbers and `blobs` the strings or raw bytes that you query by.
`write` returns at once and has no result: the runtime writes the point after the handler goes on. A successful response from this handler means it called `write`, not that a query has found the point. It raises [`Workero.Js_error`](./Workero.md#exception-Js_error) only when the runtime throws during the call. See the [limits](https://developers.cloudflare.com/analytics/analytics-engine/limits/) on the number and size of fields.


## Verify and deploy

Run `opam exec -- wrangler dev` and request `/`. Expect `ok` from the handler. Wrangler provides a local Analytics Engine simulation, but this response does not prove a data point reached the remote dataset. Deploy with `opam exec -- wrangler deploy`, send a request to the deployed Worker, then query `events` through the SQL API to check the actual data. Cloudflare creates a dataset on its first remote write. A plain workerd test does not use a Cloudflare dataset: workero's tests use a recording stub at `test/worker/services/analytics-binding.mjs`. See [local binding support](https://developers.cloudflare.com/workers/local-development/bindings-per-env/).
