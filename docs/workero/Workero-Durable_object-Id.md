
# Module `Durable_object.Id`

```ocaml
type t
```
The identity of one object.

```ocaml
val to_string : t -> string
```
64 hexadecimal digits. [`Namespace.id_from_string`](./Workero-Durable_object-Namespace.md#val-id_from_string) reads it back.

```ocaml
val name : t -> string option
```
The name given to [`Namespace.id_from_name`](./Workero-Durable_object-Namespace.md#val-id_from_name); `None` for [`Namespace.unique_id`](./Workero-Durable_object-Namespace.md#val-unique_id) and when the runtime does not report it.

```ocaml
val equal : t -> t -> bool
```
```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```