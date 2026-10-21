
# JSON

[`Workero.JSON`](./Workero-JSON.md) reads and writes JSON values of type `Jsonkit.t`. It does not re-export jsonkit. Add `jsonkit` to your Dune `libraries` and `jsonkit.ppx` to `preprocess` when you derive decoders:

```dune
(executable
 (name main)
 (modes wasm)
 (preprocess
  (pps jsonkit.ppx))
 (libraries workero jsonkit))
```
This handler decodes the request body into a record and returns JSON. The handler chooses the response for a decode error:

```ocaml
open Jsonkit.Primitives

type user = { name : string; age : int } [@@deriving json]

let handler req _env _ctx =
  match Workero.JSON.decode user_of_json req with
  | Ok user -> Workero.JSON.response (user_to_json user)
  | Error message -> Workero.JSON.error message

let () = Workero.serve handler
```
[`Workero.JSON.decode`](./Workero-JSON.md#val-decode) reads the body once and returns `Error message` for invalid JSON or when the decoder raises `Jsonkit.Of_json_error`. It does not send a 400 response. Other decoder exceptions escape unless you catch them. [`Workero.JSON.parse`](./Workero-JSON.md#val-parse) reads a `Jsonkit.t` without decoding it and also returns a result. [`Workero.JSON.request`](./Workero-JSON.md#val-request) instead raises `Jsonkit.Of_string_error` on invalid JSON; an uncaught exception makes the runtime answer with status 500\.

[`Workero.JSON.response`](./Workero-JSON.md#val-response) sends compact JSON with status 200 and `content-type: application/json; charset=utf-8` by default. [`Workero.JSON.error`](./Workero-JSON.md#val-error) sends an `{"error": message}` object with status 400 by default. You can select another status for either response.

For a binding that gives you a JavaScript value, [`Workero.JSON.of_js`](./Workero-JSON.md#val-of_js) converts its JSON representation to `Jsonkit.t`. It follows `JSON.stringify`: it drops object fields with `undefined` or function values and raises `Invalid_argument` for values with no JSON representation, such as a cyclic object or a `BigInt`. [`Workero.JSON.to_js`](./Workero-JSON.md#val-to_js) converts `Jsonkit.t` to a new JavaScript value; it raises `Invalid_argument` for `nan` or an infinite float. See [`Workero.JSON`](./Workero-JSON.md) for these functions' complete contracts.

Without the ppx, write a decoder with `Jsonkit.Of_json`. See [Requests and responses](./requests.md) for other body formats.
