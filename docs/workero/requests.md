
# Requests and responses

This page covers the types of one HTTP exchange: the [`Workero.Request`](./Workero-Request.md), the [`Workero.Response`](./Workero-Response.md), the [`Workero.URL`](./Workero-URL.md) and the [`Workero.Method`](./Workero-Method.md). It also covers JSON and the outgoing [`Workero.fetch`](./Workero.md#val-fetch).

```ocaml
let handler req _env _ctx =
  let open Workero in
  let url = Request.url req in
  match (Request.method_ req, URL.path url) with
  | GET, "/hello" ->
      let name = Option.value (URL.query url "name") ~default:"world" in
      Response.text (Printf.sprintf "hello, %s\n" name)
  | GET, "/agent" ->
      let agent = Option.value (Request.header req "user-agent") ~default:"?" in
      Response.text ~headers:[ ("x-agent", agent) ] "ok\n"
  | GET, "/where" ->
      let country = Option.value (Cf.country (Request.cf req)) ~default:"??" in
      Response.text (country ^ "\n")
  | POST, "/upload" -> Response.make ~status:201 (Request.bytes req)
  | GET, "/page" -> Response.html "<h1>hello</h1>"
  | GET, "/old" -> Response.redirect ~status:301 "/new"
  | GET, "/done" -> Response.text ~status:204 ""
  | _ -> Response.text ~status:404 "not found\n"

let () = Workero.serve handler
```

## Method

[`Workero.Method.t`](./Workero-Method.md#type-t) is a variant: `GET`, `HEAD`, `POST`, `PUT`, `DELETE`, `PATCH`, `OPTIONS` or `Other of string`. Match on [`Workero.Request.method_`](./Workero-Request.md#val-method_). [`Workero.Method.of_string`](./Workero-Method.md#val-of_string) is case-sensitive, as HTTP is. A name that is not one of the seven becomes `Other name`.


## Request

- [`Workero.Request.url`](./Workero-Request.md#val-url) is the [`Workero.URL.t`](./Workero-URL.md#type-t).
- [`Workero.Request.path`](./Workero-Request.md#val-path) is the raw path as sent. It is still percent-encoded, so `%2F` stays `%2F`. [`Workero.URL.path`](./Workero-URL.md#val-path) is decoded.
- [`Workero.Request.query_string`](./Workero-Request.md#val-query_string) is the raw query without the `"?"`, or `""`.
- [`Workero.Request.header`](./Workero-Request.md#val-header) reads one header. The name is not case-sensitive. Repeated headers are joined with `", "`.
- [`Workero.Request.header_all`](./Workero-Request.md#val-header_all) gives every value of a header as a list. Use it for `set-cookie`, which cannot be joined.
- [`Workero.Request.headers`](./Workero-Request.md#val-headers) lists all headers with lower case names, sorted by name.
- [`Workero.Request.text`](./Workero-Request.md#val-text) reads the body as UTF-8 text. Invalid UTF-8 is replaced.
- [`Workero.Request.bytes`](./Workero-Request.md#val-bytes) reads the body as raw bytes, in a `string`.
- [`Workero.Request.body`](./Workero-Request.md#val-body) gives the body as a [`Workero.Stream.t`](./Workero-Stream.md#type-t), or `None` when there is no body. See [Streams](./streams.md).
- [`Workero.Request.form_data`](./Workero-Request.md#val-form_data) reads a form. See [Forms](./forms.md).
- [`Workero.Request.clone`](./Workero-Request.md#val-clone) gives a copy. Both copies can read the body.
- [`Workero.Request.cf`](./Workero-Request.md#val-cf) gives the [`Workero.Cf.t`](./Workero-Cf.md#type-t), the Cloudflare properties of the request.
A body can be read once. [`Workero.Request.text`](./Workero-Request.md#val-text), [`Workero.Request.bytes`](./Workero-Request.md#val-bytes), [`Workero.Request.body`](./Workero-Request.md#val-body) and [`Workero.Request.form_data`](./Workero-Request.md#val-form_data) all use it up. Call [`Workero.Request.clone`](./Workero-Request.md#val-clone) first to read it again.

[`Workero.Cf`](./Workero-Cf.md) has `country`, `region`, `city`, `colo`, `timezone` and `asn`. Each one is an option. It is `None` when the runtime gives no value, for example in a local test.


## Response

- [`Workero.Response.text`](./Workero-Response.md#val-text) sends a UTF-8 text body. `status` is 200 by default.
- [`Workero.Response.html`](./Workero-Response.md#val-html) is the same with `content-type: text/html; charset=utf-8`.
- [`Workero.Response.make`](./Workero-Response.md#val-make) sends the bytes as they are, with no `content-type`.
- [`Workero.Response.empty`](./Workero-Response.md#val-empty) has a status and no body: `Response.empty 204`.
- [`Workero.Response.redirect`](./Workero-Response.md#val-redirect) sends a `location` header. The URL can be relative, such as `"/login"`. The status is 301, 302, 303, 307 or 308 (302 by default). It raises `Invalid_argument` for another status.
- [`Workero.Response.of_stream`](./Workero-Response.md#val-of_stream) and [`Workero.Response.stream`](./Workero-Response.md#val-stream) send a body in chunks. See [Streams](./streams.md).
Pass `~headers` as a list of pairs. A `content-type` in `headers` replaces the default one.

A status that allows no body (101, 204, 205 and 304\) works only with an empty body. The runtime rejects a response with one of these statuses and a body. [`Workero.Response.empty`](./Workero-Response.md#val-empty) is the simple way to make one.

A response that you got from [`Workero.fetch`](./Workero.md#val-fetch) has readers: [`Workero.Response.status`](./Workero-Response.md#val-status), [`Workero.Response.header`](./Workero-Response.md#val-header), [`Workero.Response.header_all`](./Workero-Response.md#val-header_all), [`Workero.Response.headers`](./Workero-Response.md#val-headers), [`Workero.Response.body`](./Workero-Response.md#val-body), [`Workero.Response.body_text`](./Workero-Response.md#val-body_text) and [`Workero.Response.body_bytes`](./Workero-Response.md#val-body_bytes).

The headers of a [`Workero.fetch`](./Workero.md#val-fetch) result may be read-only. To change them, make a new response with [`Workero.Response.copy`](./Workero-Response.md#val-copy):

```ocaml
let handler _req _env _ctx =
  let open Workero in
  let upstream = fetch "https://example.com/" in
  Response.copy ~headers:[ ("x-via", "workero") ] upstream

let () = Workero.serve handler
```
[`Workero.Response.copy`](./Workero-Response.md#val-copy) moves the body, so `upstream` is used up. Use [`Workero.Response.clone`](./Workero-Response.md#val-clone) when you need the body twice, for example to give one copy to [`Workero.Cache`](./Workero-Cache.md) and send the other.


### Cookies

[`Workero.Request.header`](./Workero-Request.md#val-header) and [`Workero.Response.header`](./Workero-Response.md#val-header) join repeated values with `", "`. This breaks `set-cookie`, because a cookie can contain a comma. Read it with [`Workero.Response.header_all`](./Workero-Response.md#val-header_all): it gives one entry for each `set-cookie` header.


## URL

[`Workero.URL`](./Workero-URL.md) wraps the JavaScript `URL`. It parses `http` and `https` URLs and follows the WHATWG rules.

- [`Workero.URL.path`](./Workero-URL.md#val-path) is decoded and starts with `"/"`.
- [`Workero.URL.query`](./Workero-URL.md#val-query), [`Workero.URL.query_all`](./Workero-URL.md#val-query_all) and [`Workero.URL.query_args`](./Workero-URL.md#val-query_args) give decoded values, and `"+"` in a query is a space.
- [`Workero.URL.to_string`](./Workero-URL.md#val-to_string) gives the normalised `href`: `"http://a.test"` becomes `"http://a.test/"`, and the fragment stays.
- [`Workero.URL.of_string`](./Workero-URL.md#val-of_string) gives `None` for any scheme other than `http` and `https`, and for a string that is not a URL.
Changes from the earlier parser:

- A host with `"_"`, and a URL with userinfo such as `http://user:pw@host/`, now parse. [`Workero.URL.host`](./Workero-URL.md#val-host) does not contain the userinfo.
- A query key without `=` is kept: `?a` gives `("a", "")`.
- `"+"` in a path stays `"+"`. Only a query decodes it to a space.
- A malformed escape such as `%zz` leaves the whole path undecoded.
- [`Workero.Request.url`](./Workero-Request.md#val-url) no longer raises for the cases above.

## JSON

[`Workero.JSON`](./Workero-JSON.md) reads and writes JSON with [jsonkit](https://github.com/melange-community/jsonkit). A JSON value is a `Jsonkit.t`.

```ocaml
open Jsonkit.Primitives

type user = { name : string; age : int } [@@deriving json]

let handler req _env _ctx =
  match Workero.JSON.decode user_of_json req with
  | Ok user -> Workero.JSON.response (user_to_json user)
  | Error message -> Workero.JSON.error message

let () = Workero.serve handler
```
Add `jsonkit` and `jsonkit.ppx` to the `dune` file:

```dune
(executable
 (name main)
 (modes wasm)
 (preprocess
  (pps jsonkit.ppx))
 (libraries workero jsonkit))
```
- [`Workero.JSON.decode`](./Workero-JSON.md#val-decode) reads the body and applies a decoder. It gives `Error message` for invalid JSON or when the decoder raises.
- [`Workero.JSON.parse`](./Workero-JSON.md#val-parse) reads the body and gives the `Jsonkit.t`.
- [`Workero.JSON.request`](./Workero-JSON.md#val-request) is `parse` that raises `Jsonkit.Of_string_error`. An escaping exception makes the response a 500\.
- [`Workero.JSON.response`](./Workero-JSON.md#val-response) sends JSON with status 200 and `content-type: application/json; charset=utf-8`.
- [`Workero.JSON.error`](./Workero-JSON.md#val-error) sends `{"error": message}` with status 400\.
Without the ppx, write the decoder with the combinators of `Jsonkit.Of_json`. See [`Workero.JSON`](./Workero-JSON.md) for an example.


## Calling other servers

[`Workero.fetch`](./Workero.md#val-fetch) sends an HTTP request and waits for the response headers.

```ocaml
let handler _req _env _ctx =
  let open Workero in
  let res =
    fetch ~method_:POST
      ~headers:[ ("content-type", "application/json") ]
      ~body:{|{"ping":true}|} "https://example.com/api"
  in
  match Response.status res with
  | 200 -> Response.text (Response.body_text res)
  | status -> Response.text ~status:502 (Printf.sprintf "upstream %d\n" status)

let () = Workero.serve handler
```
- `method_` is `GET` by default.
- `body` is a `string` of raw bytes. It sets no `content-type`: add one in `headers`.
- `Invalid_argument` is raised when `body` is given with `GET` or `HEAD`.
- [`Workero.Js_error`](./Workero.md#exception-Js_error) is raised when the request fails, for example on a network error.
- Read the body with [`Workero.Response.body_text`](./Workero-Response.md#val-body_text) or [`Workero.Response.body_bytes`](./Workero-Response.md#val-body_bytes).
Call [`Workero.fetch`](./Workero.md#val-fetch) only from a handler or from a function given to [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until).
