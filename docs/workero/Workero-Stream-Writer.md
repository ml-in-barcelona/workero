
# Module `Stream.Writer`

```ocaml
type t
```
```ocaml
val write : t -> string -> unit
```
Writes one chunk. Suspends until the consumer has room (back-pressure). Raises [`Js_error`](./Workero.md#exception-Js_error) when the consumer is gone, for example after a client disconnect.

```ocaml
val close : t -> unit
```
Ends the stream. Suspends.

```ocaml
val abort : ?reason:string -> t -> unit
```
Ends the stream with an error. Suspends.

```ocaml
val release : t -> unit
```
Unlocks the stream so that a new writer can lock it. The writer is unusable afterwards. Call it before [`Socket.start_tls`](./Workero-Socket.md#val-start_tls).

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
`of_js v` is a JavaScript `WritableStreamDefaultWriter`, for example one from `writable.getWriter()`.
