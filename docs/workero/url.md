
# URLs

[`Workero.Request.url`](./Workero-Request.md#val-url) returns a [`Workero.URL.t`](./Workero-URL.md#type-t) for an incoming request. Use [`Workero.URL.path`](./Workero-URL.md#val-path) to match a decoded path and [`Workero.URL.query`](./Workero-URL.md#val-query) to read a decoded query value:

```ocaml
let handler req _env _ctx =
  let open Workero in
  let url = Request.url req in
  match URL.path url with
  | "/hello" ->
      let name = Option.value (URL.query url "name") ~default:"world" in
      Response.text (Printf.sprintf "hello, %s\n" name)
  | _ -> Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
```
[`Workero.URL`](./Workero-URL.md) wraps the JavaScript `URL` and follows WHATWG parsing rules. [`Workero.URL.of_string`](./Workero-URL.md#val-of_string) accepts absolute `http` and `https` URLs. It returns `None` for other schemes or invalid input. [`Workero.Request.url`](./Workero-Request.md#val-url) raises `Invalid_argument` if the incoming URL is not an `http` or `https` URL.


## Raw and decoded paths

[`Workero.URL.path`](./Workero-URL.md#val-path) decodes percent escapes: `"/a%2Fb"` becomes `"/a/b"`. [`Workero.URL.pathname`](./Workero-URL.md#val-pathname) and [`Workero.Request.path`](./Workero-Request.md#val-path) keep the percent-encoded path. Use the raw path if encoded slashes must remain distinct from path separators. A malformed escape such as `%zz` leaves the whole `URL.path` undecoded. A `+` in a path stays `+`.

Query values follow URL search-parameter rules: `+` becomes a space. [`Workero.URL.query`](./Workero-URL.md#val-query) returns the first matching value; [`Workero.URL.query_all`](./Workero-URL.md#val-query_all) returns all matching values in order. A key without `=` has the value `""`. To keep the original query encoding, use [`Workero.Request.query_string`](./Workero-Request.md#val-query_string) or [`Workero.URL.search`](./Workero-URL.md#val-search).

See [`Workero.URL`](./Workero-URL.md) for URL parts, all query pairs, and normalized URL output. See [Requests and responses](./requests.md) for methods and headers.
