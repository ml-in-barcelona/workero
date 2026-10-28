
# Fetcher

A [`Workero.Fetcher`](./Workero-Fetcher.md) sends HTTP requests through a service binding, an assets binding, or a Durable Object stub. Use a service binding to call another Worker without a public endpoint; use an assets binding to serve files from your Worker. See the [service binding reference](https://developers.cloudflare.com/workers/runtime-apis/bindings/service-bindings/).


## Configure

Declare the target Worker in `wrangler.toml`. `binding` is the name that you pass to `of_env`:

```toml
[[services]]
binding = "BACKEND"
service = "backend-worker"
```
For an assets binding, set `directory` to the folder of files and `binding` to the name that [`Workero.Fetcher.of_env`](./Workero-Fetcher.md#val-of_env) opens:

```toml
[assets]
directory = "./public"
binding = "ASSETS"
```

## Call another Worker

```ocaml
let handler req env _ctx =
  let open Workero in
  let backend = Fetcher.of_env env "BACKEND" in
  match URL.path (Request.url req) with
  | "/users" ->
      Fetcher.fetch ~method_:POST
        ~headers:[ ("content-type", "application/json") ]
        ~body:{|{"name":"Ada"}|} backend "http://backend/users"
  | _ -> Fetcher.fetch_request backend req

let () = Workero.serve handler
```
- [`Workero.Fetcher.of_env`](./Workero-Fetcher.md#val-of_env) opens the binding. It raises `Invalid_argument` when there is no such binding, or when the binding has no `fetch` method.
- [`Workero.Fetcher.fetch`](./Workero-Fetcher.md#val-fetch) sends a request and waits for the response headers. It takes the same optional arguments as [`Workero.fetch`](./Workero.md#val-fetch). A `GET` or `HEAD` request with a body raises `Invalid_argument`.
- [`Workero.Fetcher.fetch_request`](./Workero-Fetcher.md#val-fetch_request) forwards a [`Workero.Request.t`](./Workero-Request.md#type-t) as it is. The runtime consumes the body of the request. Use [`Workero.Request.clone`](./Workero-Request.md#val-clone) first if the handler reads it too.
- [`Workero.Entrypoint.call`](./Workero-Entrypoint.md#val-call) calls an RPC method of a binding that names an entrypoint class. See [Entrypoints](./entrypoints.md).
Use an absolute URL. The service binding selects the target Worker, regardless of the host in `http://backend/users`. The target's `fetch` handler receives the request URL. A call through [`Workero.Durable_object.Namespace.get`](./Workero-Durable_object-Namespace.md#val-get) uses the same API; see [Durable Objects](./durable_objects.md).

If the target raises, the call raises [`Workero.Js_error`](./Workero.md#exception-Js_error). A target that answers with a status such as 404 or 500 is not an error: read the status with [`Workero.Response.status`](./Workero-Response.md#val-status).


## Serve a static asset

Put a file at `public/hello.txt`, configure the `assets` binding above, and use the fetcher in a handler:

```ocaml
let handler _req env _ctx =
  let assets = Workero.Fetcher.of_env env "ASSETS" in
  Workero.Fetcher.fetch assets "https://assets/hello.txt"

let () = Workero.serve handler
```
Run `wrangler dev` and request `/`. The response body is the content of `public/hello.txt`. The assets binding is simulated locally. On deploy, `wrangler deploy` uploads the directory in `assets`; there is no separate asset resource to create. See [Static Assets binding](https://developers.cloudflare.com/workers/static-assets/binding/).


## Verify the service binding

Run the target Worker in the same `wrangler dev` session by passing several configuration files:

```sh
wrangler dev -c wrangler.toml -c ../backend/wrangler.toml
```
Request `/users` locally and check that the backend receives the `POST` and JSON body. Deploy both Workers before testing the service call on Cloudflare. The workero tests exercise a service binding in `workerd`; they do not test the assets binding. See [Cloudflare service bindings](https://developers.cloudflare.com/workers/runtime-apis/bindings/service-bindings/).
