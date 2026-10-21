
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
  | GET, "/old" -> Response.redirect ~status:301 "https://example.com/new"
  | GET, "/done" -> Response.text ~status:204 ""
  | _ -> Response.text ~status:404 "not found\n"

let () = Workero.serve handler
```

## Method

[`Workero.Method.t`](./Workero-Method.md#type-t) is a variant: `GET`, `HEAD`, `POST`, `PUT`, `DELETE`, `PATCH`, `OPTIONS` or `Other of string`. Match on [`Workero.Request.method_`](./Workero-Request.md#val-method_). [`Workero.Method.of_string`](./Workero-Method.md#val-of_string) is case-sensitive, as HTTP is. A name that is not one of the seven becomes `Other name`.


## Request

- [`Workero.Request.url`](./Workero-Request.md#val-url) is the [`Workero.URL.t`](./Workero-URL.md#type-t).
- [`Workero.Request.header`](./Workero-Request.md#val-header) reads one header. The name is not case-sensitive. Repeated headers are joined with `", "`.
- [`Workero.Request.headers`](./Workero-Request.md#val-headers) lists all headers with lower case names, sorted by name.
- [`Workero.Request.text`](./Workero-Request.md#val-text) reads the body as UTF-8 text. Invalid UTF-8 is replaced.
- [`Workero.Request.bytes`](./Workero-Request.md#val-bytes) reads the body as raw bytes, in a `string`.
- [`Workero.Request.cf`](./Workero-Request.md#val-cf) gives the [`Workero.Cf.t`](./Workero-Cf.md#type-t), the Cloudflare properties of the request.
[`Workero.Cf`](./Workero-Cf.md) has `country`, `region`, `city`, `colo`, `timezone` and `asn`. Each one is an option. It is `None` when the runtime gives no value, for example in a local test.


## Response

- [`Workero.Response.text`](./Workero-Response.md#val-text) sends a UTF-8 text body. `status` is 200 by default.
- [`Workero.Response.html`](./Workero-Response.md#val-html) is the same with `content-type: text/html; charset=utf-8`.
- [`Workero.Response.make`](./Workero-Response.md#val-make) sends the bytes as they are, with no `content-type`.
- [`Workero.Response.redirect`](./Workero-Response.md#val-redirect) sends a `location` header. The URL must be absolute, and the status 301, 302, 303, 307 or 308 (302 by default). It raises `Invalid_argument` for another status.
Pass `~headers` as a list of pairs. A `content-type` in `headers` replaces the default one.

A status that allows no body (101, 204, 205 and 304\) works only with an empty body. The runtime rejects a response with one of these statuses and a body.

A response that you got from [`Workero.fetch`](./Workero.md#val-fetch) has readers: [`Workero.Response.status`](./Workero-Response.md#val-status), [`Workero.Response.header`](./Workero-Response.md#val-header), [`Workero.Response.headers`](./Workero-Response.md#val-headers), [`Workero.Response.body_text`](./Workero-Response.md#val-body_text) and [`Workero.Response.body_bytes`](./Workero-Response.md#val-body_bytes).


## URL

[`Workero.URL`](./Workero-URL.md) wraps `Js_of_ocaml.Url`. It parses `http` and `https` URLs. [`Workero.URL.path`](./Workero-URL.md#val-path) is decoded and starts with `"/"`. [`Workero.URL.query`](./Workero-URL.md#val-query), [`Workero.URL.query_all`](./Workero-URL.md#val-query_all) and [`Workero.URL.query_args`](./Workero-URL.md#val-query_args) give decoded values, and `"+"` in a query is a space.

It differs from the WHATWG `URL` of JavaScript:

- A query key without `=`, such as `?a`, is dropped.
- The path is decoded, so `%2F` and `"/"` look the same.
- [`Workero.URL.to_string`](./Workero-URL.md#val-to_string) encodes again: `%zz` becomes `%25zz`, and a space in the query becomes `%20`.
- There is no `search`, `hash` or `origin`.
- [`Workero.URL.of_string`](./Workero-URL.md#val-of_string) gives `None` for any scheme other than `http` and `https`.
- [`Workero.Request.url`](./Workero-Request.md#val-url) raises `Invalid_argument` when the URL has a host with `"_"`, or userinfo as in `http://user:pw@host/`.

## JSON

[`Workero.JSON`](./Workero-JSON.md) reads and writes JSON with [jsonkit](https://github.com/melange-community/jsonkit). A JSON value is a `Jsonkit.t`. [`Workero.JSON`](./Workero-JSON.md) does not re-export jsonkit. opam installs jsonkit with workero, but you add `jsonkit` to the `libraries` of your `dune` file to build or decode values.

```ocaml
open Jsonkit.Primitives

type user = { name : string; age : int } [@@deriving json]

let handler req _env _ctx =
  match Workero.JSON.decode user_of_json req with
  | Ok user -> Workero.JSON.response (user_to_json user)
  | Error message -> Workero.JSON.error message

let () = Workero.serve handler
```
Add `jsonkit` to `libraries`, and `jsonkit.ppx` to `preprocess` for `[@@deriving json]`:

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
