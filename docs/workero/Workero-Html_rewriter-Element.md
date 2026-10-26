
# Module `Html_rewriter.Element`

```ocaml
type t
```
```ocaml
val tag_name : t -> string
```
```ocaml
val set_tag_name : t -> string -> unit
```
```ocaml
val namespace_uri : t -> string
```
```ocaml
val removed : t -> bool
```
```ocaml
val attributes : t -> (string * string) list
```
The attributes in document order.

```ocaml
val get_attribute : t -> string -> string option
```
```ocaml
val has_attribute : t -> string -> bool
```
```ocaml
val set_attribute : t -> string -> string -> unit
```
```ocaml
val remove_attribute : t -> string -> unit
```
```ocaml
val before : t -> content -> unit
```
Insert before the start tag.

```ocaml
val after : t -> content -> unit
```
Insert after the end tag.

```ocaml
val prepend : t -> content -> unit
```
Insert right after the start tag.

```ocaml
val append : t -> content -> unit
```
Insert right before the end tag.

```ocaml
val replace : t -> content -> unit
```
Replace the element and its content.

```ocaml
val set_inner_content : t -> content -> unit
```
```ocaml
val remove : t -> unit
```
```ocaml
val remove_and_keep_content : t -> unit
```
```ocaml
val on_end_tag : t -> (End_tag.t -> unit) -> unit
```
The function runs in its own fiber, like the other handlers. Call it only inside an element handler.
