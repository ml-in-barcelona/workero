
# Module `Stream.Reader`

```ocaml
type t
```
```ocaml
val read : t -> string option
```
Next chunk, or `None` at the end. Suspends.

```ocaml
val cancel : ?reason:string -> t -> unit
```
Tells the source to stop. Suspends.

```ocaml
val release : t -> unit
```
Unlocks the stream so that [`Stream.reader`](./Workero-Stream.md#val-reader) can lock it again. The reader is unusable afterwards. Call it before [`Socket.start_tls`](./Workero-Socket.md#val-start_tls).
