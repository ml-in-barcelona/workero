
# Module `Workero.Rpc`

Values of Workers RPC calls.

Durable Object methods ([`Durable_object.call`](./Workero-Durable_object.md#val-call)) and entrypoint methods ([`Entrypoint.call`](./Workero-Entrypoint.md#val-call)) take and return a [`t`](./#type-t): a JSON-like value that can also hold the other types that RPC carries, in both directions.


### Type map

```
  `Undefined        undefined
  `Null             null
  `Bool, `Int,
  `Float            boolean, number
  `String           string
  `List             Array
  `Assoc            plain object
  `Bytes            Uint8Array (an ArrayBuffer is read as `Bytes too)
  `Date             Date, in milliseconds since the Unix epoch
  `Bigint           bigint, in decimal digits
  `Map              Map, as key and value pairs in order
  `Set              Set
  `Stream           ReadableStream
  `Stub             a service binding or a Durable Object stub
  `Function         a function
```
A number with no fraction that fits in an OCaml `int` is read as ``Int`, any other number as ``Float`. `-0` is ``Float (-0.)`. An `Error`, a typed array other than `Uint8Array`, a class instance and a `Symbol` have no constructor: reading one raises `Invalid_argument`.

A ``Stream` is consumed by the receiver. A ``Stub` stays valid as long as the runtime keeps it. A ``Function` sent in an argument can be called while the call runs; the runtime releases it when the call returns. A received ``Function` returns the result of the remote function and raises [`Js_error`](./Workero.md#exception-Js_error) when it throws.

```ocaml
type t = [ 
  | `Undefined
  | `Null
  | `Bool of bool
  | `Int of int
  | `Float of float
  | `String of string
  | `List of t list
  | `Assoc of (string * t) list
  | `Bytes of string
  | `Date of float
  | `Bigint of string
  | `Map of (t * t) list
  | `Set of t list
  | `Stream of Stream.t
  | `Stub of Fetcher.t
  | `Function of t list -> t
 ]
```
```ocaml
val of_json : Jsonkit.t -> t
```
The same value. The constructors of `Jsonkit.t` are also constructors of [`t`](./#type-t), so a handler can often build a [`t`](./#type-t) without calling this.

```ocaml
val to_json : t -> Jsonkit.t
```
Raises `Invalid_argument` when the value holds ``Undefined`, ``Bytes`, ``Date`, ``Bigint`, ``Map`, ``Set`, ``Stream`, ``Stub` or ``Function`.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
Reads a JavaScript value. Raises `Invalid_argument` for a value that has no constructor, and for a cyclic value.

```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```
Raises `Invalid_argument` for a ``Bigint` that is not decimal digits with an optional sign.

```ocaml
val call : Fetcher.t -> string -> t list -> t
```
`call stub name args` calls the RPC method `name` behind `stub`, with `args`, and waits for the result. Suspends like [`Promise.await`](./Workero-Promise.md#val-await).

Raises [`Js_error`](./Workero.md#exception-Js_error) when the method does not exist, when it raises, or when the runtime rejects the call. Raises `Invalid_argument` when an argument or the result has no [`t`](./#type-t) form.
