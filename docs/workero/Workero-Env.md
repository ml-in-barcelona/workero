
# Module `Workero.Env`

The `env` argument of a Worker handler: string and JSON-shaped variables, Worker secrets, and resource bindings. See [Variables and secrets](./env.md).

```ocaml
type t
```
```ocaml
val var : t -> string -> string option
```
A string variable or secret, or `None` when the name does not exist or does not hold a string.

```ocaml
val secret : t -> string -> string
```
`secret env name` is the string variable or secret `name`. Use it for a value that the Worker cannot run without.

Raises `Invalid_argument` when `env` has no `name`, or when it is not a string. The message names `name` and the JavaScript type; it never contains the value.

```ocaml
val json : t -> string -> Jsonkit.t option
```
An object or array variable, such as `X = { foo = 42 }` in `[vars]`. `None` when the name does not exist or holds a string, a number, a boolean or `null`. [`var`](./#val-var) returns `None` for these values.

Raises `Invalid_argument` when the value has no JSON form, as in [`JSON.of_js`](./Workero-JSON.md#val-of_js).

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```