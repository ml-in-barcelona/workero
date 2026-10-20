
# Module `Workero.Env`

```ocaml
type t
```
```ocaml
val var : t -> string -> string option
```
A string variable or secret.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```