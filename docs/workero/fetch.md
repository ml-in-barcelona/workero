
# Fetch

Use [`Workero.fetch`](./Workero.md#val-fetch) inside a handler to call another server. It waits for response headers; read the response body separately.

```ocaml
let handler _req _env _ctx =
  let open Workero in
  let upstream =
    fetch ~method_:POST
      ~headers:[ ("content-type", "application/json") ]
      ~body:{|{"ping":true}|} "https://example.com/api"
  in
  match Response.status upstream with
  | 200 -> Response.text (Response.body_text upstream)
  | status ->
      Response.text ~status:`Bad_Gateway
        (Printf.sprintf "upstream returned %d\n" status)

let () = Workero.serve handler
```
The default method is `GET`. A `~body` is raw bytes and does not set `content-type`. Include that header when the server expects one. A body with `GET` or `HEAD` raises `Invalid_argument`. A failed request raises [`Workero.Js_error`](./Workero.md#exception-Js_error); catch it if your handler must return a response on a network failure.

To stop a slow request, pass `~signal`; see [Abort and timeouts](./abort.md).

Call `fetch` inside a handler or a function passed to [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until). To forward the response without reading its body, use [`Workero.Response.copy`](./Workero-Response.md#val-copy). If you set `~headers` on the copy, include the existing [`Workero.Response.headers`](./Workero-Response.md#val-headers): `~headers` replaces them. See [Requests and responses](./requests.md) for an example and [Streams](./streams.md) for passing through a large body.

To call another Worker through a service binding or access static assets, use [Fetcher](./fetcher.md). See [`Workero.fetch`](./Workero.md#val-fetch) for the complete interface.
