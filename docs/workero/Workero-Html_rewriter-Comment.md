
# Module `Html_rewriter.Comment`

```ocaml
type t
```
```ocaml
val text : t -> string
```
```ocaml
val set_text : t -> string -> unit
```
```ocaml
val removed : t -> bool
```
```ocaml
val before : t -> content -> unit
```
```ocaml
val after : t -> content -> unit
```
```ocaml
val replace : t -> content -> unit
```
```ocaml
val remove : t -> unit
```