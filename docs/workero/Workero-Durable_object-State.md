
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


### Hibernatable WebSockets

Sockets accepted with [`accept_websocket`](./#val-accept_websocket) stay connected while the object is evicted from memory. The runtime creates the object again when a message arrives and calls the `websocket_*` handlers of [`make`](./Workero-Durable_object.md#val-make). Keep per-socket state in [`Websocket.serialize_attachment`](./Workero-Websocket.md#val-serialize_attachment), not in memory. A socket accepted with [`Websocket.accept`](./Workero-Websocket.md#val-accept) does not hibernate; do not mix the two on one socket.

```ocaml
val accept_websocket : ?tags:string list -> t -> Websocket.t -> unit
```
Accepts the server end of a [`Websocket.pair`](./Workero-Websocket.md#val-pair). `tags` are at most 10 strings of at most 256 characters; a violation raises [`Js_error`](./Workero.md#exception-Js_error).

```ocaml
val websockets : ?tag:string -> t -> Websocket.t list
```
The accepted sockets, or those with `tag`.

```ocaml
val tags : t -> Websocket.t -> string list
```
```ocaml
val set_websocket_auto_response : 
  t ->
  request:string ->
  response:string ->
  unit
```
Answers a text message equal to `request` with `response`, without waking the object.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```