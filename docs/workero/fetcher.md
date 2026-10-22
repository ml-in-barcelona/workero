
# Fetcher

A [`Workero.Fetcher`](./Workero-Fetcher.md) sends a request to another Worker, to static assets, or to a Durable Object. It is the type of a [service binding](https://developers.cloudflare.com/workers/runtime-apis/bindings/service-bindings/).


## Configure

Declare the target Worker in `wrangler.toml`. `binding` is the name that you pass to `of_env`:

```toml
[[services]]
binding = "BACKEND"
service = "backend-worker"
```
Static assets have a binding too. Name it with `binding` under `[assets]`:

```toml
[assets]
directory = "./public"
binding = "ASSETS"
```

## Use

```ocaml
let handler req env _ctx =
  let open Workero in
  let backend = Fetcher.of_env env "BACKEND" in
  match URL.path (Request.url req) with
  | "/users" ->
      let res =
        Fetcher.fetch ~method_:POST
          ~headers:[ ("content-type", "application/json") ]
          ~body:{|{"name":"Ada"}|} backend "http://backend/users"
      in
      Response.text ~status:(`Status (Response.status res)) (Response.body_text res)
  | _ -> Fetcher.fetch_request backend req

let () = Workero.serve handler
```
- [`Workero.Fetcher.of_env`](./Workero-Fetcher.md#val-of_env) opens the binding. It raises `Invalid_argument` when there is no such binding, or when the binding has no `fetch` method.
- [`Workero.Fetcher.fetch`](./Workero-Fetcher.md#val-fetch) sends a request and waits for the response headers. It takes the same optional arguments as [`Workero.fetch`](./Workero.md#val-fetch). A `GET` or `HEAD` request with a body raises `Invalid_argument`.
- [`Workero.Fetcher.fetch_request`](./Workero-Fetcher.md#val-fetch_request) forwards a [`Workero.Request.t`](./Workero-Request.md#type-t) as it is. The runtime consumes the body of the request. Use [`Workero.Request.clone`](./Workero-Request.md#val-clone) first if the handler reads it too.
The URL must be absolute. A service binding ignores the host, so write any host, such as `http://backend/users`. The target Worker sees the path and the query. The target receives the request in its `fetch` handler.

If the target raises, the call raises [`Workero.Js_error`](./Workero.md#exception-Js_error). A target that answers with a status such as 404 or 500 is not an error: read the status with [`Workero.Response.status`](./Workero-Response.md#val-status).


## Test locally

Run the target Worker in the same `wrangler dev` session by passing several configuration files:

```sh
npx wrangler dev -c wrangler.toml -c ../backend/wrangler.toml
```
The tests of workero run against a `service` binding in `workerd`. They do not cover an assets binding, which has the same `fetch` method.
