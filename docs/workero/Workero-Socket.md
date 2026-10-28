
# Module `Workero.Socket`

Outbound TCP sockets, like `connect` from `cloudflare:sockets`. `index.js` imports `connect` on every build, so a program needs no setup. See [Sockets](./socket.md).

Functions that say "Suspends" suspend like [`Promise.await`](./Workero-Promise.md#val-await) and raise [`Js_error`](./Workero.md#exception-Js_error) when the runtime rejects.

```ocaml
type t
```
An open or opening TCP connection.

```ocaml
type secure_transport = 
  | Off (* Plain TCP. *)
  | On (* TLS from the first byte. *)
  | Starttls (* Plain TCP that start_tls upgrades to TLS. *)
```
```ocaml
type info = {
  remote_address : string option; (* The address of the server, if known. *)
  local_address : string option; (* The local address, if known. *)
}
```
Address information of an open connection. The runtime may leave a field out.

```ocaml
val connect : 
  ?secure_transport:secure_transport ->
  ?allow_half_open:bool ->
  host:string ->
  port:int ->
  unit ->
  t
```
`connect ~host ~port ()` starts a connection and returns at once. It raises [`Js_error`](./Workero.md#exception-Js_error) only when the runtime throws from its `connect` call, for an address that it rejects at once. Any other failed connection shows as an error from [`opened`](./#val-opened), from [`closed`](./#val-closed) and from the reads and writes. Call [`opened`](./#val-opened) to wait for the connection.

`secure_transport` is `Off` by default. `allow_half_open` is `false` by default: when the server ends its side, the runtime closes the write side too. With `true`, the write side stays open.

Raises `Invalid_argument` when `host` is empty or `port` is outside 1 to 65535, and `Failure` when the runtime has no `cloudflare:sockets` (a program run outside a Worker, for example in Node.js).

raises [`Js_error`](./Workero.md#exception-Js_error) when the runtime throws from its connect call. Which addresses it rejects at once is up to the runtime; the tests do not cover it.
```ocaml
val opened : t -> info
```
Waits until the connection is up and gives its [`info`](./#type-info). Suspends. Raises [`Js_error`](./Workero.md#exception-Js_error) when the connection fails.

```ocaml
val upgraded : t -> bool
```
The `upgraded` property of the JavaScript socket: `true` when the runtime reports that the socket was upgraded to TLS. In `workerd` tests it is `false` before and after [`start_tls`](./#val-start_tls), on the old and the new socket.

```ocaml
val closed : t -> unit
```
Waits until the socket is closed. Suspends. Raises [`Js_error`](./Workero.md#exception-Js_error) when the socket closes with an error.

```ocaml
val reader : t -> Stream.Reader.t
```
The read side. [`Stream.Reader.read`](./Workero-Stream-Reader.md#val-read) gives `None` when the server ends its side. Locks the stream: call it once for each socket. Raises [`Js_error`](./Workero.md#exception-Js_error) on a second call.

```ocaml
val writer : t -> Stream.Writer.t
```
The write side. [`Stream.Writer.close`](./Workero-Stream-Writer.md#val-close) ends it and sends a TCP end of stream. Locks the stream: call it once for each socket. Raises [`Js_error`](./Workero.md#exception-Js_error) on a second call.

```ocaml
val close : t -> unit
```
Closes both sides. Suspends.

```ocaml
val start_tls : ?expected_server_hostname:string -> t -> t
```
`start_tls socket` upgrades a socket made with `Starttls` and returns the secure socket. Release the reader and writer of `socket` before the call, and use [`reader`](./#val-reader) and [`writer`](./#val-writer) of the result. The old `socket` stops working. `expected_server_hostname` replaces the host name that the server certificate must match.

Raises [`Js_error`](./Workero.md#exception-Js_error) when `socket` was not made with `Starttls`, or when the runtime rejects the upgrade.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```