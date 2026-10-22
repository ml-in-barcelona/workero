
# Module `Workero.Response`

```ocaml
type t
```
```ocaml
val text : 
  ?status:[< Status.with_body ] ->
  ?headers:(string * string) list ->
  string ->
  t
```
A UTF-8 text body. The runtime sets `content-type` to `text/plain;charset=UTF-8` unless `headers` has one. `status` is 200 by default. The type of `status` leaves out the statuses that allow no body (``No_Content`, ``Reset_Content`, ``Not_Modified`); use [`empty`](./#val-empty) for those. ``Status n` can still name one: with the empty string it works, and the body is sent as no body.

Raises `Invalid_argument` when ``Status n` has `n` outside 200 to 599 (the runtime accepts no other code), or when `n` is 204, 205 or 304 and the body is not empty. The same holds for [`html`](./#val-html), [`make`](./#val-make), [`of_stream`](./#val-of_stream), [`stream`](./#val-stream), [`copy`](./#val-copy) and [`empty`](./#val-empty).

```ocaml
val html : 
  ?status:[< Status.with_body ] ->
  ?headers:(string * string) list ->
  string ->
  t
```
Like [`text`](./#val-text), with `content-type: text/html; charset=utf-8` unless `headers` has a `content-type`.

```ocaml
val make : 
  ?status:[< Status.with_body ] ->
  ?headers:(string * string) list ->
  string ->
  t
```
`make body` sends the bytes of `body` as they are, with no `content-type` unless `headers` has one.

```ocaml
val empty : 
  ?headers:(string * string) list ->
  [< Status.no_body | Status.with_body ] ->
  t
```
`empty status` has no body and no `content-type`. `empty `No_Content` is a 204\.

```ocaml
val of_stream : 
  ?status:[< Status.with_body ] ->
  ?headers:(string * string) list ->
  Stream.t ->
  t
```
`of_stream s` is `new Response(s, init)`. Use it to pass an upstream body through without copying.

```ocaml
val stream : 
  ?status:[< Status.with_body ] ->
  ?headers:(string * string) list ->
  Context.t ->
  (Stream.Writer.t -> unit) ->
  t
```
`stream ctx f` answers at once. `f` runs in its own fiber (see [`Context.wait_until`](./Workero-Context.md#val-wait_until)), may suspend, and ends the body when it returns. If `f` raises, the body is aborted and the error is written with `console.error`.

```ocaml
val redirect : ?status:[< Status.redirect ] -> string -> t
```
`redirect url` answers with a `location` header. `url` may be relative, such as `"/login"`. An absolute URL is normalized by the runtime. `status` is ``Found` by default.

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
val copy : 
  ?status:[< Status.with_body ] ->
  ?headers:(string * string) list ->
  t ->
  t
```
`copy res` builds a response with the same body stream. `res` and its copy share that stream; only one can consume it. Use [`clone`](./#val-clone) first if you need two independently readable bodies. `status` replaces the original status; `headers` replaces the entire original header list. Without them, the original status and headers are kept. Use `copy` to edit the headers of a `fetch` result, which may be read-only.

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