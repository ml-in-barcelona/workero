
# Module `Html_rewriter.End_tag`

The closing tag of an element.

```ocaml
type t
```
```ocaml
val name : t -> string
```
```ocaml
val set_name : t -> string -> unit
```
```ocaml
val before : t -> content -> unit
```
```ocaml
val after : t -> content -> unit
```
```ocaml
val remove : t -> unit
```