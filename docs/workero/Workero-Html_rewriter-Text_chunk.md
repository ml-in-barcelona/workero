
# Module `Html_rewriter.Text_chunk`

A piece of a text node. A text node can arrive in several chunks.

```ocaml
type t
```
```ocaml
val text : t -> string
```
One chunk. The last chunk of a node is often `""`. Join the chunks until [`last_in_text_node`](./#val-last_in_text_node) is `true`.

```ocaml
val last_in_text_node : t -> bool
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