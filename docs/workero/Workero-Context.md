
# Module `Workero.Context`

The `ctx` argument of a Worker handler.

```ocaml
type t
```
```ocaml
val wait_until : t -> (unit -> unit) -> unit
```
`wait_until ctx f` runs `f` in its own fiber and keeps the Worker alive until `f` returns, after the response is sent. `f` may suspend with [`Promise.await`](./Workero-Promise.md#val-await). If `f` raises, the runtime logs the error. The request that called `wait_until` and other requests are not affected.

```ocaml
val pass_through_on_exception : t -> unit
```
`pass_through_on_exception ctx` makes the runtime send the request to the origin server when the handler raises, instead of answering with an error. It needs a route with an origin: it has no effect on `workers.dev` or in workerd without one.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```