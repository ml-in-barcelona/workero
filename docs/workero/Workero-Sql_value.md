
# Module `Workero.Sql_value`

A value of an SQL column, as sent to and received from a JavaScript SQL API such as D1.

```ocaml
type t = 
  | Null
  | Int of int64
  | Float of float
  | Text of string
  | Blob of string (* Blob holds raw bytes.SQL APIs on the Workers runtime carry numbers as JavaScript numbers, which are 64-bit floats, so a read cannot tell an SQL INTEGER from a REAL. A number with no fractional part within ±253 is read as Int, also from a REAL column: a REAL holding 2.0 reads as Int 2L. Any other number is read as Float. An INTEGER beyond 253 reaches OCaml already rounded by the runtime, and is read as Float (or as Int 9007199254740992L when it rounds to exactly 253), never as its exact Int. A written Int is exact only within ±253. *)
```
```ocaml
type row = (string * t) list
```
The columns of a row in result order, with their names.

```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```
The JavaScript value to bind: `null`, a number, a string or a `Uint8Array`.

Raises `Invalid_argument` for an `Int` beyond ±253, which a JavaScript number cannot hold exactly.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
Reads a JavaScript value: `null` or `undefined` is `Null`; a number with no fractional part within ±253 is `Int`; any other number is `Float`; a `bigint` is `Int`, exact in 64 bits; a string is `Text`; an `ArrayBuffer`, a typed array or an array of byte numbers is `Blob`.

Raises `Invalid_argument` for any other JavaScript value, and for a `bigint` outside the int64 range.
