
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

Raises `Jsonkit.Of_string_error` when the body is not valid JSON. The payload describes the syntax error. A handler that lets it escape makes the runtime answer with status 500\. Use [`parse`](https://ml-in-barcelona.github.io/workero/workero/Workero/JSON/index.html#val-parse) or [`decode`](https://ml-in-barcelona.github.io/workero/workero/Workero/JSON/index.html#val-decode) to handle the error and choose a response.

```ocaml
val parse : Request.t -> (Jsonkit.t, string) Stdlib.result
```
Reads the body and returns `Ok json`, or `Error message` when the body is not valid JSON.

```ocaml
val decode : (Jsonkit.t -> 'a) -> Request.t -> ('a, string) Stdlib.result
```
`decode of_json req` parses the body and applies `of_json`. `of_json` is a jsonkit decoder, for example `user_of_json` from `[@@deriving json]`, or `Jsonkit.Of_json.(list int)`. `Error message` when the body is not valid JSON or when `of_json` raises `Jsonkit.Of_json_error`. Other decoder exceptions escape. This function does not send a response; use [`error`](https://ml-in-barcelona.github.io/workero/workero/Workero/JSON/index.html#val-error) when you want to return status 400\.
