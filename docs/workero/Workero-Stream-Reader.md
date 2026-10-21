
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
