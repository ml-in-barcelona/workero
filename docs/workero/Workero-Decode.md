
# Module `Workero.Decode`

Decoders for raw JavaScript values, for [`Promise.of_js`](./Workero-Promise.md#val-of_js). A decoder raises `Invalid_argument` naming the expected and the actual JavaScript type.

```ocaml
type 'a t = Js_of_ocaml.Js.Unsafe.any -> 'a
```
```ocaml
val js : Js_of_ocaml.Js.Unsafe.any t
```
The value, undecoded.

```ocaml
val unit : unit t
```
Accepts any value and drops it.

```ocaml
val string : string t
```
```ocaml
val int : int t
```
Raises `Invalid_argument` for a number with a fraction or outside the range of the OCaml `int`.

```ocaml
val float : float t
```
```ocaml
val bool : bool t
```
```ocaml
val bytes : string t
```
An `ArrayBuffer`, a typed array or an array of byte numbers, as raw bytes.

```ocaml
val option : 'a t -> 'a option t
```
`None` for `null` and `undefined`.

```ocaml
val list : 'a t -> 'a list t
```
A JavaScript array.

```ocaml
val field : string -> 'a t -> 'a t
```
`field name d` decodes the property `name` of an object or function.
