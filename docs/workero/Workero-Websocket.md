
# Module `Workero.Websocket`

WebSockets served by the Worker, read by pulling events with [`receive`](./#val-receive).

Functions that raise [`Js_error`](./Workero.md#exception-Js_error) do so when the runtime throws. `receive` suspends like [`Promise.await`](./Workero-Promise.md#val-await).

```ocaml
type t
```
```ocaml
type message = 
  | Text of string
  | Binary of string
```
```ocaml
type event = 
  | Message of message
  | Close of {
    code : int;
    reason : string;
    was_clean : bool;
  }
  | Failed of string (* The error event. A Close follows. *)
```
```ocaml
type pair = {
  client : t;
  server : t;
}
```
```ocaml
val pair : unit -> pair
```
`new WebSocketPair()`.

```ocaml
val accept : t -> unit
```
`accept()` and starts queueing events. Sets `binaryType` to `"arraybuffer"`, so binary messages arrive as bytes. Call it before any `receive`.

```ocaml
val send : t -> message -> unit
```
Raises [`Js_error`](./Workero.md#exception-Js_error) when the socket is closed.

```ocaml
val receive : t -> event
```
The next event, in arrival order. Suspends while the queue is empty. After `Close` it returns the same `Close` again. One fiber at a time may wait: a second concurrent `receive` raises `Invalid_argument`.

```ocaml
val close : ?code:int -> ?reason:string -> t -> unit
```
```ocaml
val response : t -> Response.t
```
Status 101 with `webSocket` set; give it the `client` of a `pair`.

```ocaml
val upgrade : Context.t -> (t -> unit) -> Response.t
```
`upgrade ctx f` makes a pair, accepts the server end, runs `f server` in its own fiber (`Context.wait_until`), and returns the 101 response at once. When `f` returns, the socket closes with code 1000 if it is still open. If `f` raises, it closes with 1011 and writes the error with `console.error`.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```