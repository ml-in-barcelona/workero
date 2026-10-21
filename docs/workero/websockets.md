
# WebSockets

[`Workero.Websocket.upgrade`](./Workero-Websocket.md#val-upgrade) accepts a WebSocket connection. Your function gets the server end. It reads events with a loop.

```ocaml
let handler _req _env ctx =
  let open Workero in
  Websocket.upgrade ctx (fun ws ->
      let rec loop () =
        match Websocket.receive ws with
        | Message (Text s) ->
            Websocket.send ws (Text ("echo: " ^ s));
            loop ()
        | Message (Binary b) ->
            Websocket.send ws (Binary b);
            loop ()
        | Close _ -> Websocket.close ws
        | Failed _ -> loop ()
      in
      loop ())

let () = Workero.serve handler
```
[`Workero.Websocket.upgrade`](./Workero-Websocket.md#val-upgrade) returns the `101` response at once. Your function runs in its own fiber, through [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until).

- When your function returns, the socket closes with code 1000, if it is still open.
- If your function raises, the socket closes with code 1011\. The error goes to `console.error`.
A socket that stays open was tested for 60 seconds on Cloudflare.

Handle upgrade requests only. Check the `upgrade` header first when the same route also serves normal requests.


## Events

[`Workero.Websocket.receive`](./Workero-Websocket.md#val-receive) gives the next [`Workero.Websocket.event`](./Workero-Websocket.md#type-event). It waits while no event is ready.

- `Message (Text s)` and `Message (Binary b)`: a message. Binary data is a `string` of bytes.
- `Close { code; reason; was_clean }`: the peer closed the connection. A second [`Workero.Websocket.receive`](./Workero-Websocket.md#val-receive) gives the same `Close`.
- `Failed message`: the `error` event. A `Close` follows it.
Events come in the order they arrived. The queue starts when [`Workero.Websocket.accept`](./Workero-Websocket.md#val-accept) runs, so no message is lost between the accept and your first [`Workero.Websocket.receive`](./Workero-Websocket.md#val-receive).

Only one fiber may wait in [`Workero.Websocket.receive`](./Workero-Websocket.md#val-receive). A second concurrent call raises `Invalid_argument`.


## Why no callbacks

A callback that JavaScript calls cannot wait. See [Waiting for JavaScript](./async.md). A receive loop runs in direct style, so it can call [`Workero.fetch`](./Workero.md#val-fetch), [`Workero.KV`](./Workero-KV.md) or [`Workero.Promise.await`](./Workero-Promise.md#val-await) between two messages.


## Send and close

- [`Workero.Websocket.send`](./Workero-Websocket.md#val-send) sends `Text s` or `Binary b`. It raises [`Workero.Js_error`](./Workero.md#exception-Js_error) when the socket is closed.
- [`Workero.Websocket.close`](./Workero-Websocket.md#val-close) closes with an optional `code` and `reason`.

## Without upgrade

[`Workero.Websocket.upgrade`](./Workero-Websocket.md#val-upgrade) is [`Workero.Websocket.pair`](./Workero-Websocket.md#val-pair), [`Workero.Websocket.accept`](./Workero-Websocket.md#val-accept) and [`Workero.Websocket.response`](./Workero-Websocket.md#val-response) in one call. Use the parts to keep the `client` end, or to start the loop yourself.


## Not supported yet

- A WebSocket that the Worker opens to another server.
- Hibernation, which lets a Durable Object sleep between messages.