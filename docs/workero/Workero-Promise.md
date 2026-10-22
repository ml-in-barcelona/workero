
# Module `Workero.Promise`

A JavaScript `Promise` of an OCaml value.

The type is backed by `Js_of_ocaml.Promise`: a promise resolved with another promise is boxed, so `'a t t` holds a promise of a promise, where a raw JavaScript `Promise` would flatten it.

```ocaml
type +'a t
```
```ocaml
type error
```
A rejection reason. JavaScript allows any value, so the type is opaque.

```ocaml
exception Js_error of error
```
Raised by [`await`](./#val-await) when the awaited promise rejects, and by the bindings when the runtime throws. It carries the original reason, so a handler can re-raise or inspect it with [`error_to_js`](./#val-error_to_js). Use it through [`Workero.Js_error`](./Workero.md#exception-Js_error), the documented name.

```ocaml
val error_of_exn : exn -> error
```
A rejection that carries an OCaml exception. [`await`](./#val-await) re-raises that exception. When it reaches the runtime, it is a JavaScript `Error` whose message is `Printexc.to_string`.

```ocaml
val error_of_string : string -> error
```
`error_of_string msg` is a JavaScript `Error` with message `msg`.

```ocaml
val error_to_string : error -> string
```
The reason converted with JavaScript `String`, for example `"Error: nope"`.

```ocaml
val error_of_js : Js_of_ocaml.Js.Unsafe.any -> error
```
```ocaml
val error_to_js : error -> Js_of_ocaml.Js.Unsafe.any
```
```ocaml
val make : (resolve:('a -> unit) -> reject:(error -> unit) -> unit) -> 'a t
```
`make executor` is `new Promise(executor)`. An exception raised by `executor` rejects the promise, like a throw in JavaScript.

```ocaml
val resolve : 'a -> 'a t
```
`Promise.resolve`.

```ocaml
val reject : error -> 'a t
```
`Promise.reject`.

```ocaml
val await : 'a t -> 'a
```
`await p` suspends the current request until `p` settles. It returns the resolved value. For a rejection made by [`error_of_exn`](./#val-error_of_exn), `map`, `bind`, `make` or `of_js`, it re-raises the original OCaml exception. For any other rejection it raises [`Js_error`](./#exception-Js_error). It works inside the handlers given to [`Workero.serve`](./Workero.md#val-serve), [`Workero.scheduled`](./Workero.md#val-scheduled) and [`Workero.queue`](./Workero.md#val-queue), inside the `init`, `fetch`, `alarm`, `websocket_message`, `websocket_close` and `websocket_error` handlers of [`Durable_object.make`](./Workero-Durable_object.md#val-make), and inside functions passed to [`Context.wait_until`](./Workero-Context.md#val-wait_until), [`Durable_object.State.wait_until`](./Workero-Durable_object-State.md#val-wait_until) and [`Durable_object.State.block_concurrency_while`](./Workero-Durable_object-State.md#val-block_concurrency_while). It cannot suspend inside the function passed to [`Durable_object.register`](./Workero-Durable_object.md#val-register) or [`Durable_object.Storage.transaction_sync`](./Workero-Durable_object-Storage.md#val-transaction_sync); the latter raises `Invalid_argument` and rolls back.

```ocaml
val map : ('a -> 'b) -> 'a t -> 'b t
```
An exception raised by the function rejects the result, see [`await`](./#val-await).

```ocaml
val bind : ('a -> 'b t) -> 'a t -> 'b t
```
Like [`map`](./#val-map), for a function that returns a promise.

```ocaml
val all : 'a t list -> 'a list t
```
Resolves with every value, in order, or rejects with the first rejection.

```ocaml
val race : 'a t list -> 'a t
```
Settles like the first promise to settle.

```ocaml
val any : 'a t list -> 'a t
```
Resolves with the first value. When all reject, rejects with an `AggregateError`.

```ocaml
val all_settled : 'a t list -> ('a, error) Stdlib.result list t
```
Resolves when every promise has settled. It never rejects.

```ocaml
val of_js : 
  decode:(Js_of_ocaml.Js.Unsafe.any -> 'a) ->
  Js_of_ocaml.Js.Unsafe.any ->
  'a t
```
`of_js ~decode p` reads a raw JavaScript Promise and applies `decode` to its resolved value. If `decode` raises, [`await`](./#val-await) re-raises the original OCaml exception. See [`Decode`](./Workero-Decode.md).

```ocaml
val to_js : 'a t -> Js_of_ocaml.Js.Unsafe.any
```
The underlying JavaScript Promise. A thenable it resolves with is boxed, so raw JavaScript code sees a box and not the thenable.
