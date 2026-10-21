
# Module `Durable_object.State`

```ocaml
type t
```
The `ctx` of an object.

```ocaml
val id : t -> Id.t
```
```ocaml
val storage : t -> Storage.t
```
```ocaml
val wait_until : t -> (unit -> unit) -> unit
```
Like [`Context.wait_until`](./Workero-Context.md#val-wait_until).

```ocaml
val block_concurrency_while : t -> (unit -> 'a) -> 'a
```
`block_concurrency_while state f` runs `f` in its own fiber and lets no other event reach the object until `f` returns. `f` may call [`Promise.await`](./Workero-Promise.md#val-await). If `f` raises, the runtime resets the object and fails the running requests, including the one that called this function; the next request creates the object again. Suspends. Raises `Invalid_argument` when called from the function given to [`register`](./Workero-Durable_object.md#val-register); use `~init` there.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```