
# Module `Workero.Env`

The `env` argument of a Worker handler holds bindings: variables, secrets and configured resources.

```ocaml
type t
```
```ocaml
val var : t -> string -> string option
```
`var env name` returns `Some value` for a string variable or secret. It returns `None` when `name` is missing or its value is not a string. This lookup does not suspend. Use a resource module's `of_env` for objects.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```