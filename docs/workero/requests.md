
# Requests and responses

Use [`Workero.Request`](./Workero-Request.md) to read an incoming request and [`Workero.Response`](./Workero-Response.md) to answer it. Match on [`Workero.Request.method_`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-method_) and the path to select a route:

```ocaml
let handler req _env _ctx =
  let open Workero in
  let url = Request.url req in
  match (Request.method_ req, URL.path url) with
  | GET, "/hello" ->
      let name = Option.value (URL.query url "name") ~default:"world" in
      Response.text (Printf.sprintf "hello, %s\n" name)
  | POST, "/echo" -> Response.text (Request.text req)
  | _ -> Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
```

## Read the request body

[`Workero.Request.text`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-text) reads the whole body as UTF-8 text. [`Workero.Request.bytes`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-bytes) reads raw bytes into a string. Both consume the body. To read a body in chunks, get its stream with [`Workero.Request.body`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-body) and read the stream. Getting the stream does not itself consume it. A request without a body returns `None`. See [Streams](./streams.md) for stream readers and [Forms and file uploads](./forms.md) for form bodies.

A body can be consumed only once. Call [`Workero.Request.clone`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-clone) before reading if you need to read it twice.


## Work with headers

Header names are case-insensitive. [`Workero.Request.header`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-header) and [`Workero.Response.header`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-header) read a joined value. For an ordinary repeated header, [`Workero.Request.header_all`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-header_all) and [`Workero.Response.header_all`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-header_all) return a list with one joined value, not one item per original header. For `set-cookie`, `header_all` returns one item per cookie. Do not split a `set-cookie` value at commas: a cookie can contain a comma.


## Send a response

[`Workero.Response.text`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-text) sends text, [`Workero.Response.html`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-html) sends HTML, and [`Workero.Response.make`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-make) sends raw bytes. Pass `~status` and `~headers` to set the status and headers. For a response without a body, use `Response.empty `No_Content`. To send a redirect, use [`Workero.Response.redirect`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-redirect). Named statuses that do not allow a body do not type-check with the body constructors. A numeric ``Status n` still type-checks: an invalid status or a non-empty body with status 204, 205, or 304 raises `Invalid_argument` at runtime. See [Streams](./streams.md) for a streamed response and [`Workero.Response`](./Workero-Response.md) for the status rules.

To forward a fetched response with one added header, keep its existing headers when you call [`Workero.Response.copy`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-copy):

```ocaml
let handler _req _env _ctx =
  let open Workero in
  let upstream = fetch "https://example.com/" in
  let headers = Response.headers upstream @ [ ("x-via", "workero") ] in
  Response.copy ~headers upstream

let () = Workero.serve handler
```
`Response.copy ~headers` replaces the entire header list. Without `~headers`, it keeps the existing headers. Both responses share one body stream, which can be consumed only once. Use [`Workero.Response.clone`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-clone) before reading if you need two copies. See [Fetch](./fetch.md) for outgoing requests.


## Reference

See [`Workero.Method`](./Workero-Method.md), [`Workero.Request`](./Workero-Request.md), [`Workero.Response`](./Workero-Response.md), [`Workero.Status`](./Workero-Status.md), and [`Workero.Cf`](./Workero-Cf.md) for the complete API. For URL parsing and query parameters, see [URLs](./url.md).
