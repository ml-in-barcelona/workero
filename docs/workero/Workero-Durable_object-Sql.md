
# Module `Durable_object.Sql`

The SQLite database of an object. Calls are synchronous: they never suspend. An SQL error raises [`Js_error`](./Workero.md#exception-Js_error). Numbers are JavaScript numbers, so an `Int` is exact only within ±253; see [`Sql_value`](./Workero-Sql_value.md).

```ocaml
type t
```
```ocaml
val query : ?params:Sql_value.t list -> t -> string -> Sql_value.row list
```
`query sql_db statement` runs `statement`, with `params` bound to its `?` marks in order, and returns every row.

```ocaml
val run : ?params:Sql_value.t list -> t -> string -> int
```
Runs a statement and returns the number of rows it wrote. It reads the cursor to its end first, because the count is final only then.

```ocaml
val database_size : t -> int
```
The size of the database in bytes.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```