
# Module `Workero.Response`

```ocaml
type t
```
```ocaml
val text : ?status:int -> ?headers:(string * string) list -> string -> t
```
A UTF-8 text body. The runtime sets `content-type` to `text/plain;charset=UTF-8` unless `headers` has one. `status` is 200 by default. A status that allows no body (101, 204, 205, 304\) works with the empty string, which is sent as no body. A non-empty body with such a status is rejected by the runtime when the response is built.

```ocaml
val html : ?status:int -> ?headers:(string * string) list -> string -> t
```
Like [`text`](./#val-text), with `content-type: text/html; charset=utf-8` unless `headers` has a `content-type`.

```ocaml
val make : ?status:int -> ?headers:(string * string) list -> string -> t
```
`make body` sends the bytes of `body` as they are, with no `content-type` unless `headers` has one.

```ocaml
val redirect : ?status:int -> string -> t
```
`redirect url` answers with a `location` header. `url` must be absolute, such as `"https://example.com/login"`; the runtime rejects a relative one like `"/login"`. `status` is 302 by default.

Raises `Invalid_argument` when `status` is not one of 301, 302, 303, 307 and 308\.

```ocaml
val status : t -> int
```
```ocaml
val header : t -> string -> string option
```
See [`Request.header`](./Workero-Request.md#val-header).

```ocaml
val headers : t -> (string * string) list
```
See [`Request.headers`](./Workero-Request.md#val-headers).

```ocaml
val body_text : t -> string
```
Reads the whole body as UTF-8 text. Suspends like [`Promise.await`](./Workero-Promise.md#val-await).

```ocaml
val body_bytes : t -> string
```
Reads the whole body as raw bytes. Suspends like [`Promise.await`](./Workero-Promise.md#val-await).

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```