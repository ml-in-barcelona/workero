
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
`header req name` is the value of header `name`, matched without regard to letter case. Ordinary repeated headers are joined with `", "`. Use [`header_all`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-header_all) to read each `set-cookie` separately.

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
The body as a stream; `None` when the request has none. Getting the stream does not consume it. Reading from the stream does.

```ocaml
val form_data : t -> Form_data.t
```
Parses a multipart or urlencoded body with the platform parser. Suspends like [`Promise.await`](https://ml-in-barcelona.github.io/workero/workero/Workero/Promise/index.html#val-await). Raises [`Js_error`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#exception-Js_error) for another content type.

```ocaml
val clone : t -> t
```
`request.clone()`; both copies can read the body.

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