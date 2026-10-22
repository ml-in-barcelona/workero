
# Module `Workflow.Duration`

```ocaml
type t
```
A length of time, sent to the runtime in milliseconds.

```ocaml
val ms : int -> t
```
`ms n`, like [`seconds`](./#val-seconds), [`minutes`](./#val-minutes), [`hours`](./#val-hours) and [`days`](./#val-days), is `n` units of time. These functions raise `Invalid_argument` for a negative count.

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