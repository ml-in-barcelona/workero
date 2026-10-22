
# Requests and responses

Read an incoming [`Workero.Request`](./Workero-Request.md) and return a [`Workero.Response`](./Workero-Response.md) from a handler. Match the method and path to choose a response:

```ocaml
let handler req _env _ctx =
  let open Workero in
  match (Request.method_ req, URL.path (Request.url req)) with
  | GET, "/hello" -> Response.text "hello\n"
  | POST, "/echo" -> Response.text (Request.text req)
  | _ -> Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
```

## Read a request

[`Workero.Request.method_`](./Workero-Request.md#val-method_) returns a [`Workero.Method.t`](./Workero-Method.md#type-t). Use [`Workero.Request.url`](./Workero-Request.md#val-url) for a parsed URL, or [`Workero.Request.path`](./Workero-Request.md#val-path) for a raw, percent-encoded path. See [URLs](./url.md) for query values and decoded paths.

[`Workero.Request.text`](./Workero-Request.md#val-text) reads the entire body as UTF-8 text, replacing invalid UTF-8. [`Workero.Request.bytes`](./Workero-Request.md#val-bytes) reads raw bytes into a string. These readers consume the body. To read it in chunks, get its stream with [`Workero.Request.body`](./Workero-Request.md#val-body). Getting the stream does not itself consume it; reading the stream does. A request with no body returns `None`. See [Streams](./streams.md) and [Forms](./forms.md) for other body readers.

A body can be consumed only once. Call [`Workero.Request.clone`](./Workero-Request.md#val-clone) before reading if you need two copies. [`Workero.Request.cf`](./Workero-Request.md#val-cf) returns Cloudflare request properties, such as country and colo; individual properties can be absent.


## Work with headers

Header names are case-insensitive. [`Workero.Request.header`](./Workero-Request.md#val-header) and [`Workero.Response.header`](./Workero-Response.md#val-header) read a joined value. For an ordinary repeated header, `header_all` returns a list with one joined value, not one item per original header. For `set-cookie`, [`Workero.Request.header_all`](./Workero-Request.md#val-header_all) and [`Workero.Response.header_all`](./Workero-Response.md#val-header_all) return one item per cookie. Do not split cookies at commas because a cookie can contain a comma.


## Send a response

[`Workero.Response.text`](./Workero-Response.md#val-text) sends text, [`Workero.Response.html`](./Workero-Response.md#val-html) sends HTML, and [`Workero.Response.make`](./Workero-Response.md#val-make) sends raw bytes. Pass `~status` or `~headers` to set them. Use `Response.empty `No_Content` when the response has no body, or [`Workero.Response.redirect`](./Workero-Response.md#val-redirect) for a redirect. See [Streams](./streams.md) for streamed responses and [JSON](./json.md) for JSON responses.

Named no-body statuses (``No_Content`, ``Reset_Content`, ``Not_Modified`) do not type-check with the body constructors. A numeric ``Status n` still type-checks: a status outside 200 to 599, or a non-empty body with status 204, 205, or 304, raises `Invalid_argument` at runtime. An empty string body with one of these statuses sends no body. See [`Workero.Status`](./Workero-Status.md) for status names.

To forward an upstream response with one additional header, retain its original headers:

```ocaml
let handler _req _env _ctx =
  let open Workero in
  let upstream = fetch "https://example.com/" in
  let headers = Response.headers upstream @ [ ("x-via", "workero") ] in
  Response.copy ~headers upstream

let () = Workero.serve handler
```
`Response.copy ~headers` replaces the entire header list. Without `~headers`, it keeps the existing headers. The original and copy share one body stream; only one can consume it. Use [`Workero.Response.clone`](./Workero-Response.md#val-clone) before reading if you need two copies. See [Fetch](./fetch.md) for outgoing requests.

See [`Workero.Request`](./Workero-Request.md), [`Workero.Response`](./Workero-Response.md), [`Workero.Method`](./Workero-Method.md), [`Workero.Status`](./Workero-Status.md), and [`Workero.Cf`](./Workero-Cf.md) for the complete interfaces.
