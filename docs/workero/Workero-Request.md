
# Module `Workero.Request`

```ocaml
type t
```
```ocaml
val method_ : t -> Method.t
```
```ocaml
val url : t -> URL.t
```
The request URL.

Raises `Invalid_argument` when `Js_of_ocaml.Url` cannot parse it. A host containing `"_"` and a URL with userinfo, like `http://user:pw@host/`, are not parsed.

```ocaml
val header : t -> string -> string option
```
`header req name` is the value of header `name`, matched without regard to letter case. Repeated headers are joined with `", "`.

```ocaml
val headers : t -> (string * string) list
```
All headers, with lower case names, sorted by name, as `Headers` iterates them.

```ocaml
val body_text : t -> string
```
Reads the whole body as UTF-8 text. Invalid UTF-8 is replaced.

```ocaml
val body_bytes : t -> string
```
Reads the whole body as raw bytes.

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