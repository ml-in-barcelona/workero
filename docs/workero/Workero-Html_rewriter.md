
# Module `Workero.Html_rewriter`

Rewrite an HTML response while it streams, like the JavaScript `HTMLRewriter`. The runtime parses the body and calls your functions for the nodes that match. OCaml does not read the body, so a large page costs no OCaml memory except the nodes that you handle.

Every handler function runs in its own fiber and may call [`Promise.await`](./Workero-Promise.md#val-await), [`Workero.fetch`](./Workero.md#val-fetch) and the other bindings. The runtime waits for a function to return before it parses on. Do not rely on the order of work between two handlers that suspend.

A node is valid only while its handler runs. Use it later and the runtime raises [`Workero.Js_error`](./Workero.md#exception-Js_error). Do not keep a node in a reference.

An exception raised by a handler stops the parse. The body of the transformed response errors with the exception text, and the original body is canceled. A client that already received bytes sees a truncated response.

```ocaml
type t
```
```ocaml
val create : unit -> t
```
A rewriter with no handlers. It does no I/O, so it may be a toplevel value.

```ocaml
type content = 
  | Text of string (* The runtime escapes the string: <b> becomes &lt;b&gt;. *)
  | Html of string (* The string is inserted as markup. *)
  | Text_stream of Stream.t (* The runtime reads the stream and escapes it, like Text. The stream is used up. *)
  | Html_stream of Stream.t (* The runtime reads the stream and inserts it as markup, like Html. The stream is used up. *)
  | Text_response of Response.t (* The runtime reads the body of the response and escapes it. The status and headers are ignored. The response is used up. *)
  | Html_response of Response.t (* The runtime reads the body of the response and inserts it as markup. The status and headers are ignored. The response is used up. *)
```
```ocaml
module End_tag : sig ... end
```
The closing tag of an element.

```ocaml
module Element : sig ... end
```
```ocaml
module Text_chunk : sig ... end
```
A piece of a text node. A text node can arrive in several chunks.

```ocaml
module Comment : sig ... end
```
```ocaml
module Doctype : sig ... end
```
```ocaml
module Document_end : sig ... end
```
```ocaml
val on : 
  ?element:(Element.t -> unit) ->
  ?text:(Text_chunk.t -> unit) ->
  ?comments:(Comment.t -> unit) ->
  string ->
  t ->
  t
```
`on ?element selector rw` adds handlers for the nodes that match `selector` and returns `rw`, so calls chain: `create () |> on ~element f "a" |> on ~text g "p"`. `selector` is a CSS selector in the subset that Cloudflare documents: type, universal, class, id, attribute forms, `:nth-child`, `:first-child`, `:nth-of-type`, `:first-of-type`, `:not`, descendant and child.

`text` and `comments` run for the text and comment nodes inside the matching elements.

Raises `Invalid_argument` when no handler is given. Raises [`Workero.Js_error`](./Workero.md#exception-Js_error) when the runtime rejects `selector`.

```ocaml
val on_document : 
  ?doctype:(Doctype.t -> unit) ->
  ?text:(Text_chunk.t -> unit) ->
  ?comments:(Comment.t -> unit) ->
  ?end_:(Document_end.t -> unit) ->
  t ->
  t
```
Adds handlers for the whole document. `end_` runs once, after the last node. Raises `Invalid_argument` when no handler is given.

```ocaml
val transform : t -> Response.t -> Response.t
```
`transform rw response` is a new response with the same status and headers. Its body streams: the runtime parses `response` as the body is read. `response` is used up. To use the result twice, for example in a cache write, call [`Response.clone`](./Workero-Response.md#val-clone) on it first.
