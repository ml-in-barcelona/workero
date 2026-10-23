
# Module `Workero.Email`

Email Routing. The handler that [`Workero.email`](./Workero.md#val-email) registers receives a [`t`](./#type-t): a message that Cloudflare Email Routing delivered to the Worker. The handler can read the message, forward it, reply to it or reject it.

Functions that say "Suspends" suspend like [`Promise.await`](./Workero-Promise.md#val-await) and raise [`Js_error`](./Workero.md#exception-Js_error) when the runtime rejects.

```ocaml
type t
```
A `ForwardableEmailMessage`.

```ocaml
val from : t -> string
```
The envelope sender (`MAIL FROM`). It can differ from the `From` header.

```ocaml
val to_ : t -> string
```
The envelope recipient (`RCPT TO`).

```ocaml
val header : t -> string -> string option
```
`header message name` is the value of header `name` of the message, matched without regard to letter case. Repeated headers are joined with `", "`.

```ocaml
val header_all : t -> string -> string list
```
Every value of a header; see [`Request.header_all`](./Workero-Request.md#val-header_all).

```ocaml
val headers : t -> (string * string) list
```
All headers, with lower case names, sorted by name, as `Headers` iterates them.

```ocaml
val raw_size : t -> int
```
The size of the raw message in bytes. It is known before the body is read.

```ocaml
val raw : t -> Stream.t
```
The raw message (headers and body, as sent) as a stream. The stream can be read once. Use it to read a large message in chunks instead of holding it in memory with [`raw_bytes`](./#val-raw_bytes).

```ocaml
val raw_text : t -> string
```
Reads the whole raw message as UTF-8 text. Invalid UTF-8 is replaced. Suspends. Raises [`Js_error`](./Workero.md#exception-Js_error) when the raw message was read before.

```ocaml
val raw_bytes : t -> string
```
Reads the whole raw message as raw bytes. The bytes are copied into the memory of the program, so a large message needs that much memory. Suspends. Raises [`Js_error`](./Workero.md#exception-Js_error) when the raw message was read before.

```ocaml
val set_reject : t -> string -> unit
```
`set_reject message reason` rejects the message with a permanent SMTP error. The sender gets `reason`. Call it instead of [`forward`](./#val-forward) or [`reply`](./#val-reply).

```ocaml
val forward : ?headers:(string * string) list -> t -> string -> unit
```
`forward message address` forwards the message to `address`, which must be a verified destination address of the account. `headers` adds headers to the forwarded message; the runtime accepts only names that start with `"X-"`. Suspends.

```ocaml
val reply : t -> from:string -> to_:string -> string -> unit
```
`reply message ~from ~to_ raw` sends `raw`, a complete message with headers, as a reply to `message`. `from` must be an address of the Worker's domain and `to_` the sender. `raw` needs a `Message-ID` header and an `In-Reply-To` header that holds the `Message-ID` of `message`. Suspends.

raises [`Js_error`](./Workero.md#exception-Js_error) when the runtime rejects the reply, or when the runtime has no cloudflare:email module (workerd).
```ocaml
val reply_stream : t -> from:string -> to_:string -> Stream.t -> unit
```
Like [`reply`](./#val-reply), with the raw message as a stream, for a message that is large or built in pieces. The stream must hold the same complete message, with the same headers. The runtime reads the stream, so do not read it yourself. Suspends.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```