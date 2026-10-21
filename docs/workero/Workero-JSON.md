
# Module `Workero.JSON`

JSON requests and responses for workero (`Workero.JSON`).

A JSON value is a `Jsonkit.t` from [jsonkit](https://github.com/melange-community/jsonkit). This module does not re-export jsonkit. opam installs jsonkit with workero. To build or decode values, add `jsonkit` to the `libraries` of your `dune` file. To derive decoders with `[@@deriving json]`, also add `(preprocess (pps jsonkit.ppx))`. Then write:

```ocaml
open Jsonkit.Primitives

type user = { name : string; age : int } [@@deriving json]

let handler req _env _ctx =
  match Workero.JSON.decode user_of_json req with
  | Ok user -> Workero.JSON.response (user_to_json user)
  | Error message -> Workero.JSON.error message
```
Without the ppx, write the decoder by hand:

```ocaml
let user_of_json json =
  Jsonkit.Of_json.
    { name = json |> field "name" string; age = json |> field "age" int }
```
```ocaml
val response : 
  ?status:[< Status.with_body ] ->
  ?headers:(string * string) list ->
  Jsonkit.t ->
  Response.t
```
`response json` is a response with status 200 and the compact JSON text as body. It adds `content-type: application/json; charset=utf-8` unless `headers` already has a `content-type` (any letter case). Non-ASCII characters are sent as UTF-8.

```ocaml
val error : ?status:[< Status.with_body ] -> string -> Response.t
```
`error message` is a response with status 400 and the body `{"error": message}`.

```ocaml
val request : Request.t -> Jsonkit.t
```
Reads the whole body and parses it as JSON.

Raises `Jsonkit.Of_string_error` when the body is not valid JSON. The payload describes the syntax error. A handler that lets it escape makes the runtime answer with status 500; use [`parse`](./#val-parse) or [`decode`](./#val-decode) to answer with 400\.

```ocaml
val parse : Request.t -> (Jsonkit.t, string) Stdlib.result
```
Like [`request`](./#val-request). `Error message` when the body is not valid JSON.

```ocaml
val decode : (Jsonkit.t -> 'a) -> Request.t -> ('a, string) Stdlib.result
```
`decode of_json req` parses the body and applies `of_json`. `of_json` is a jsonkit decoder, for example `user_of_json` from `[@@deriving json]`, or `Jsonkit.Of_json.(list int)`. `Error message` when the body is not valid JSON or when `of_json` raises `Jsonkit.Of_json_error`.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> Jsonkit.t
```
`of_js v` is the JSON form of the JavaScript value `v`, the one that `JSON.stringify` gives. A `Date` becomes a string, and a key whose value is `undefined` or a function is dropped, as in `JSON.stringify`.

Raises `Invalid_argument` when `v` has no JSON form (`undefined`, a function or a symbol), or when `JSON.stringify` throws, for example on a cyclic object or a `BigInt`.

```ocaml
val to_js : Jsonkit.t -> Js_of_ocaml.Js.Unsafe.any
```
`to_js json` is a new JavaScript value, built with `JSON.parse`.

Raises `Invalid_argument` when `json` holds a float that JSON cannot write: `nan` or an infinity.
