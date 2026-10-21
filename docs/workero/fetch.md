
# Fetch

Use [`Workero.fetch`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-fetch) inside a handler to call another server. It waits for the response headers. Read the body separately with [`Workero.Response.body_text`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-body_text) or [`Workero.Response.body_bytes`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-body_bytes).

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
The default method is `GET`. A `~body` is raw bytes and does not set `content-type`; include that header when the server expects one. A body with `GET` or `HEAD` raises `Invalid_argument`. A failed request raises [`Workero.Js_error`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#exception-Js_error); catch it if your handler must return a response for a network failure.

Call `fetch` inside a handler or a function passed to [`Workero.Context.wait_until`](https://ml-in-barcelona.github.io/workero/workero/Workero/Context/index.html#val-wait_until). To forward the response without reading its body, use [`Workero.Response.copy`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-copy). If you set `~headers` on the copy, include the existing [`Workero.Response.headers`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-headers) because `~headers` replaces them. See [Requests and responses](./requests.md) for an example and [Streams](./streams.md) for passing through a large body.

See [`Workero.fetch`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-fetch) and [`Workero.Response`](./Workero-Response.md) for the complete API.
