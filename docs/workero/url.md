
# URLs

[`Workero.Request.url`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-url) gives you a [`Workero.URL.t`](https://ml-in-barcelona.github.io/workero/workero/Workero/URL/index.html#type-t) for the incoming request. Use [`Workero.URL.path`](https://ml-in-barcelona.github.io/workero/workero/Workero/URL/index.html#val-path) to match a decoded path and [`Workero.URL.query`](https://ml-in-barcelona.github.io/workero/workero/Workero/URL/index.html#val-query) to read a decoded query value:

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
[`Workero.URL`](./Workero-URL.md) wraps JavaScript `URL` and follows WHATWG URL parsing rules. [`Workero.URL.of_string`](https://ml-in-barcelona.github.io/workero/workero/Workero/URL/index.html#val-of_string) accepts absolute `http` and `https` URLs. It returns `None` for other schemes or invalid input. [`Workero.Request.url`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-url) raises `Invalid_argument` if the incoming URL is not an `http` or `https` URL.


## Raw paths and decoded paths

[`Workero.URL.path`](https://ml-in-barcelona.github.io/workero/workero/Workero/URL/index.html#val-path) decodes percent escapes: `"/a%2Fb"` becomes `"/a/b"`. [`Workero.URL.pathname`](https://ml-in-barcelona.github.io/workero/workero/Workero/URL/index.html#val-pathname) and [`Workero.Request.path`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-path) keep the percent-encoded path. Use a raw path if encoded slashes must remain distinct from path separators. A malformed escape such as `%zz` leaves the whole `URL.path` undecoded. A `+` in a path stays `+`.

Query values are decoded with URL search-parameter rules: `+` becomes a space. [`Workero.URL.query`](https://ml-in-barcelona.github.io/workero/workero/Workero/URL/index.html#val-query) returns the first matching value, and [`Workero.URL.query_all`](https://ml-in-barcelona.github.io/workero/workero/Workero/URL/index.html#val-query_all) returns all matching values in order. A key without `=` has the value `""`. To keep the original query encoding, use [`Workero.Request.query_string`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-query_string) or [`Workero.URL.search`](https://ml-in-barcelona.github.io/workero/workero/Workero/URL/index.html#val-search).

See [`Workero.URL`](./Workero-URL.md) for the complete API, including URL parts, all query pairs, and normalized URL output. See [Requests and responses](./requests.md) for method and header handling.
