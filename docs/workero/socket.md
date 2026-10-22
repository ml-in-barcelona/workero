
# Sockets

[`Workero.Socket`](./Workero-Socket.md) opens outbound TCP connections, like `connect` from [`cloudflare:sockets`](https://developers.cloudflare.com/workers/runtime-apis/tcp-sockets/). Use it to talk to a database, a mail server or any other TCP service that HTTP does not reach.

There is nothing to configure. `workero build` writes `index.js` with `import { connect } from "cloudflare:sockets"` on every build, so a program that does not use sockets pays nothing for it.


## Use

```ocaml
let handler _req _env _ctx =
  let open Workero in
  let socket = Socket.connect ~host:"gopher.floodgap.com" ~port:70 () in
  Socket.opened socket;
  let writer = Socket.writer socket in
  Stream.Writer.write writer "/\r\n";
  Stream.Writer.close writer;
  let reader = Socket.reader socket in
  let buf = Buffer.create 1024 in
  let rec loop () =
    match Stream.Reader.read reader with
    | Some chunk -> Buffer.add_string buf chunk; loop ()
    | None -> ()
  in
  loop ();
  Socket.close socket;
  Response.text (Buffer.contents buf)

let () = Workero.serve handler
```
- [`Workero.Socket.connect`](./Workero-Socket.md#val-connect) returns at once. A refused connection shows in [`Workero.Socket.opened`](./Workero-Socket.md#val-opened), which suspends until the connection is up.
- [`Workero.Socket.reader`](./Workero-Socket.md#val-reader) and [`Workero.Socket.writer`](./Workero-Socket.md#val-writer) give the [`Workero.Stream`](./Workero-Stream.md) readers and writers. Each locks its stream, so call each one once for each socket, or unlock the stream with [`Workero.Stream.Reader.release`](./Workero-Stream-Reader.md#val-release) or [`Workero.Stream.Writer.release`](./Workero-Stream-Writer.md#val-release). [`Workero.Stream.Writer.write`](./Workero-Stream-Writer.md#val-write) waits when the server is slow to read (back-pressure).
- [`Workero.Stream.Reader.read`](./Workero-Stream-Reader.md#val-read) gives `None` when the server ends its side. [`Workero.Stream.Writer.close`](./Workero-Stream-Writer.md#val-close) ends yours.
- [`Workero.Socket.close`](./Workero-Socket.md#val-close) closes both sides. [`Workero.Socket.closed`](./Workero-Socket.md#val-closed) waits for the socket to close.

## TLS

`~secure_transport:On` uses TLS from the first byte. For a protocol that starts in plain text, such as PostgreSQL, connect with `~secure_transport:Starttls`, exchange the opening messages, unlock the streams, then call [`Workero.Socket.start_tls`](./Workero-Socket.md#val-start_tls):

```ocaml
open Workero

let handler _req _env _ctx =
  let socket =
    Socket.connect ~secure_transport:Starttls ~host:"db.example.com" ~port:5432
      ()
  in
  Socket.opened socket;
  let reader = Socket.reader socket and writer = Socket.writer socket in
  Stream.Writer.write writer "plain text opening message";
  ignore (Stream.Reader.read reader);
  Stream.Reader.release reader;
  Stream.Writer.release writer;
  let secure = Socket.start_tls socket in
  let writer = Socket.writer secure in
  Stream.Writer.write writer "encrypted message";
  Socket.close secure;
  Response.text "done"

let () = Workero.serve handler
```
`start_tls` returns a new socket. The old socket stops working. The runtime fails the upgrade while a reader or writer still locks a stream, so release both first.


## Half-open sockets

By default, when the server ends its side, the runtime also closes your write side. Pass `~allow_half_open:true` to keep it open, for a protocol where the client sends after the server has finished.


## Test

`workerd` can run a `connect` handler in a Worker that is the `globalOutbound` of the Worker under test. That Worker then plays the TCP server. The tests of workero do this: see `test/worker/upstream.mjs`. With this setup, TLS cannot be tested: `~secure_transport:On` fails with an error that mentions TLS, and `start_tls` fails with "startTls() is not supported on this connection". To test TLS, connect to a real network service.


## Limits

Cloudflare refuses connections to Cloudflare addresses, loopback addresses and port 25\. [`Workero.Socket.connect`](./Workero-Socket.md#val-connect) raises [`Workero.Js_error`](./Workero.md#exception-Js_error) for them, or [`Workero.Socket.opened`](./Workero-Socket.md#val-opened) does. See [Support and known issues](./known_issues.md).
