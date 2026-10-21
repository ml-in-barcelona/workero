
# Module `Workero.D1`

A Cloudflare D1 database, bound in `wrangler.toml` with `[[d1_databases]]`. Each function suspends like [`Promise.await`](./Workero-Promise.md#val-await) and raises [`Js_error`](./Workero.md#exception-Js_error) when the runtime rejects, for example on an SQL error.

```ocaml
type t
```
```ocaml
val of_env : Env.t -> string -> t
```
`of_env env name` is the database bound as `name`.

Raises `Invalid_argument` when `env` has no binding `name`.

```ocaml
type value = Sql_value.t = 
  | Null
  | Int of int64
  | Float of float
  | Text of string
  | Blob of string (* An SQL value, see Sql_value. D1 carries numbers as JavaScript numbers, so an Int is exact within ±253 only and Float 1.0 reads back as Int 1L. *)
```
```ocaml
type row = (string * value) list
```
The columns of a row in result order, with their names.

```ocaml
val query : ?params:value list -> t -> string -> row list
```
`query db sql ~params` runs `sql` with `params` bound to its `?` marks, in order, and returns the rows. Columns keep the order of the `SELECT`, and repeated or numeric-looking names are kept as they are. Raises `Invalid_argument` when the platform answers with a malformed result: a column name that is not text, or a row of another length.

```ocaml
val run : ?params:value list -> t -> string -> int
```
`run db sql ~params` runs a statement that returns no rows, such as `INSERT` or `CREATE TABLE`, and returns the number of rows it changed.
