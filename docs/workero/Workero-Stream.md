
# Module `Workero.Stream`

Byte streams: a JavaScript `ReadableStream` and its readers and writers.

Functions that say "Suspends" suspend like [`Promise.await`](./Workero-Promise.md#val-await) and raise [`Js_error`](./Workero.md#exception-Js_error) when the runtime rejects.

```ocaml
type t
```
A JavaScript `ReadableStream` of bytes.

```ocaml
module Reader : sig ... end
```
```ocaml
module Writer : sig ... end
```
```ocaml
val reader : t -> Reader.t
```
Locks the stream. Raises [`Js_error`](./Workero.md#exception-Js_error) when it is already locked.

```ocaml
val iter : (string -> unit) -> t -> unit
```
`iter f s` calls `f` on every chunk until the end. Suspends.

```ocaml
val pipe : unit -> Writer.t * t
```
An identity `TransformStream`: what is written is read from `t`.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```