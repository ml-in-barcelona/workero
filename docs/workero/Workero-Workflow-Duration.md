
# Module `Workflow.Duration`

```ocaml
type t
```
A length of time, sent to the runtime in milliseconds.

```ocaml
val ms : int -> t
```
```ocaml
val seconds : int -> t
```
```ocaml
val minutes : int -> t
```
```ocaml
val hours : int -> t
```
```ocaml
val days : int -> t
```
Raise `Invalid_argument` for a negative count.
