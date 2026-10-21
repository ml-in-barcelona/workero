
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
