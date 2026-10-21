
# Module `Workero.Promise`

A JavaScript `Promise`, bound directly.

```ocaml
type 'a t
```
```ocaml
val make : (resolve:('a -> unit) -> reject:(string -> unit) -> unit) -> 'a t
```
`make executor` is `new Promise(executor)`. `reject msg` rejects with a JavaScript `Error` whose message is `msg`.

```ocaml
val resolve : 'a -> 'a t
```
`Promise.resolve`.

```ocaml
val reject : string -> 'a t
```
`Promise.reject (new Error msg)`.

```ocaml
val await : 'a t -> 'a
```
`await p` suspends the current request until `p` settles. It returns the resolved value or raises [`Workero.Js_error`](./Workero.md#exception-Js_error). It works inside the handlers given to [`Workero.serve`](./Workero.md#val-serve) and [`Workero.scheduled`](./Workero.md#val-scheduled), and inside the function given to [`Context.wait_until`](./Workero-Context.md#val-wait_until).

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> 'a t
```
Views a raw JavaScript Promise. The caller states the type of the resolved value: a JavaScript string must be typed `Js_of_ocaml.Js.js_string Js_of_ocaml.Js.t`, not `string`.

```ocaml
val to_js : 'a t -> Js_of_ocaml.Js.Unsafe.any
```