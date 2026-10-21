
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
val empty : ?headers:(string * string) list -> int -> t
```
`empty status` has no body and no `content-type`.

```ocaml
val of_stream : ?status:int -> ?headers:(string * string) list -> Stream.t -> t
```
`of_stream s` is `new Response(s, init)`. Use it to pass an upstream body through without copying.

```ocaml
val stream : 
  ?status:int ->
  ?headers:(string * string) list ->
  Context.t ->
  (Stream.Writer.t -> unit) ->
  t
```
`stream ctx f` answers at once. `f` runs in its own fiber (see [`Context.wait_until`](./Workero-Context.md#val-wait_until)), may suspend, and ends the body when it returns. If `f` raises, the body is aborted and the error is written with `console.error`.

```ocaml
val redirect : ?status:int -> string -> t
```
`redirect url` answers with a `location` header. `url` may be relative, such as `"/login"`. An absolute URL is normalized by the runtime. `status` is 302 by default.

Raises `Invalid_argument` when `status` is not one of 301, 302, 303, 307 and 308\.

```ocaml
val status : t -> int
```
```ocaml
val header : t -> string -> string option
```
See [`Request.header`](./Workero-Request.md#val-header). A `set-cookie` value is not usable here: use [`header_all`](./#val-header_all).

```ocaml
val header_all : t -> string -> string list
```
See [`Request.header_all`](./Workero-Request.md#val-header_all).

```ocaml
val headers : t -> (string * string) list
```
See [`Request.headers`](./Workero-Request.md#val-headers).

```ocaml
val body : t -> Stream.t option
```
The body as a stream; `None` for a null body.

```ocaml
val clone : t -> t
```
`response.clone()`; both copies can read the body.

```ocaml
val copy : ?status:int -> ?headers:(string * string) list -> t -> t
```
`copy res` is `new Response(res.body, init)`: the same body, moved, so `res` is used up. `status` and `headers` replace those of `res`. Use it to edit the headers of a `fetch` result, which may be frozen.

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