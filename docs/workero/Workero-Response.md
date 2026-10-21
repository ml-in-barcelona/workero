
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
A UTF-8 text body. The runtime sets `content-type` to `text/plain;charset=UTF-8` unless `headers` has one. `status` is 200 by default. The type of `status` leaves out the statuses that allow no body (``No_Content`, ``Reset_Content`, ``Not_Modified`); use [`empty`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-empty) for those. ``Status n` can still name one: with the empty string it works, and the body is sent as no body.

Raises `Invalid_argument` when ``Status n` has `n` outside 200 to 599 (the runtime accepts no other code), or when `n` is 204, 205 or 304 and the body is not empty. The same holds for [`html`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-html), [`make`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-make), [`of_stream`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-of_stream), [`stream`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-stream), [`copy`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-copy) and [`empty`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-empty).

```ocaml
val html : 
  ?status:[< Status.with_body ] ->
  ?headers:(string * string) list ->
  string ->
  t
```
Like [`text`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-text), with `content-type: text/html; charset=utf-8` unless `headers` has a `content-type`.

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
`stream ctx f` starts `f` in its own fiber (see [`Context.wait_until`](https://ml-in-barcelona.github.io/workero/workero/Workero/Context/index.html#val-wait_until)). Synchronous work before the first suspension can delay the response. `f` may suspend and ends the body when it returns. If `f` raises, the body is aborted and the error is written with `console.error`.

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
See [`Request.header`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-header). A `set-cookie` value is not usable here: use [`header_all`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-header_all).

```ocaml
val header_all : t -> string -> string list
```
See [`Request.header_all`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-header_all).

```ocaml
val headers : t -> (string * string) list
```
See [`Request.headers`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-headers).

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
`copy res` is `new Response(res.body, init)`. Both responses share the same body stream, which can be consumed only once. Use [`clone`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-clone) first if both responses need to read it. Omitted `status` and `headers` keep those of `res`. Supplied `headers` replace the entire header list, so include existing headers if you need to preserve them. Use it to edit the headers of a `fetch` result, which may be frozen.

```ocaml
val body_text : t -> string
```
Reads the whole body as UTF-8 text. Suspends like [`Promise.await`](https://ml-in-barcelona.github.io/workero/workero/Workero/Promise/index.html#val-await).

```ocaml
val body_bytes : t -> string
```
Reads the whole body as raw bytes. Suspends like [`Promise.await`](https://ml-in-barcelona.github.io/workero/workero/Workero/Promise/index.html#val-await).

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```