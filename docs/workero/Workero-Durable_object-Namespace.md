
# Module `Durable_object.Namespace`

```ocaml
type t
```
A `[durable_objects]` binding.

```ocaml
type location_hint = 
  | Wnam
  | Enam
  | Sam
  | Weur
  | Eeur
  | Apac
  | Oc
  | Afr
  | Me
```
```ocaml
type jurisdiction = 
  | Eu
  | Fedramp
```
```ocaml
val of_env : Env.t -> string -> t
```
Raises `Invalid_argument` when `env` has no binding `name`, or when the binding is not a Durable Object namespace.

```ocaml
val id_from_name : t -> string -> Id.t
```
The same name always gives the same id.

```ocaml
val id_from_string : t -> string -> Id.t
```
Reads an id written by [`Id.to_string`](./Workero-Durable_object-Id.md#val-to_string). Raises [`Js_error`](./Workero.md#exception-Js_error) when the string is not an id of this namespace.

```ocaml
val unique_id : ?jurisdiction:jurisdiction -> t -> Id.t
```
A new random id.

```ocaml
val get : ?location_hint:location_hint -> t -> Id.t -> Fetcher.t
```
The stub of an object: a [`Fetcher.t`](./Workero-Fetcher.md#type-t) whose `fetch` reaches the `fetch` handler of the object. The runtime creates the object on its first request. `location_hint` matters only when the object is created.

```ocaml
val get_by_name : ?location_hint:location_hint -> t -> string -> Fetcher.t
```
`get_by_name ns name` is `get ns (id_from_name ns name)`.
