
# Module `Workero.Request`

```ocaml
type t
```
```ocaml
val method_ : t -> Method.t
```
```ocaml
val url : t -> Workero__.Url.t
```
The request URL.

Raises `Invalid_argument` when it is not an `http` or `https` URL.

```ocaml
val path : t -> string
```
The raw path as sent, percent-encoded, starting with `"/"`. `"%2F"` stays `"%2F"`.

```ocaml
val query_string : t -> string
```
The raw query without the `"?"`; `""` when there is none.

```ocaml
val header : t -> string -> string option
```
`header req name` is the value of header `name`, matched without regard to letter case. Repeated headers are joined with `", "`. Use [`header_all`](./#val-header_all) for `cookie` lists and `set-cookie`.

```ocaml
val header_all : t -> string -> string list
```
Every value of a header; one entry per `set-cookie`, one joined entry for other names.

```ocaml
val headers : t -> (string * string) list
```
All headers, with lower case names, sorted by name, as `Headers` iterates them.

```ocaml
val text : t -> string
```
Reads the whole body as UTF-8 text. Invalid UTF-8 is replaced.

```ocaml
val bytes : t -> string
```
Reads the whole body as raw bytes.

```ocaml
val body : t -> Stream.t option
```
The body as a stream; `None` when the request has none. Getting the stream does not consume the body. Reading it does.

```ocaml
val form_data : t -> Form_data.t
```
Parses a multipart or urlencoded body with the platform parser. Suspends like [`Promise.await`](./Workero-Promise.md#val-await). Raises [`Js_error`](./Workero.md#exception-Js_error) for another content type.

```ocaml
val clone : t -> t
```
`request.clone()`; both copies can read the body.

```ocaml
val signal : t -> Abort_signal.t
```
The signal of the incoming request. It aborts when the runtime detects that the client canceled the request. It needs the `enable_request_signal` compatibility flag, which the project template sets; without the flag the signal never aborts. Workerd delivers the abort for a streamed response; it gave none for a handler that only awaits a timer, so do not rely on it to detect every disconnect. Do not pass it to work that must outlive the client, such as a [`Workero.fetch`](./Workero.md#val-fetch) in [`Context.wait_until`](./Workero-Context.md#val-wait_until).

```ocaml
val cf : t -> Cf.t
```
The Cloudflare properties of the request.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```