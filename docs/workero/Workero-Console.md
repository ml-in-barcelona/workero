
# Module `Workero.Console`

The global `console`. Each call writes one entry to the Workers logs, with its level. Unlike `print_string`, it needs no flush.

```ocaml
val log : string -> unit
```
```ocaml
val info : string -> unit
```
```ocaml
val warn : string -> unit
```
```ocaml
val error : string -> unit
```
```ocaml
val debug : string -> unit
```