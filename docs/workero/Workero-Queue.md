
# Module `Workero.Queue`

Cloudflare Queues. A [`t`](./#type-t) sends messages through a producer binding in `wrangler.toml` (`[[queues.producers]]`). A [`Workero.queue`](./Workero.md#val-queue) handler consumes batches from a queue configured under `[[queues.consumers]]`, not through a producer binding. See [Queue](./queue.md) for a complete Worker.

Under `open Workero`, this module hides `Stdlib.Queue`. Write `Stdlib.Queue` to reach the standard one.

```ocaml
type t
```
```ocaml
val of_env : Env.t -> string -> t
```
`of_env env name` is the queue producer bound as `name`.

Raises `Invalid_argument` when `env` has no binding `name`, or when the binding has no `send` and `sendBatch` methods.

```ocaml
type body = 
  | Json of Jsonkit.t (* Content type json. *)
  | Text of string (* Content type text. *)
  | Bytes of string (* Content type bytes: raw bytes. *)
```
The body of a message. Each constructor sets the content type, so a body and its content type cannot disagree.

```ocaml
type message
```
A message to send in a batch, made by [`message`](./#val-message).

```ocaml
val message : ?delay_seconds:int -> body -> message
```
`message body` is a message for [`send_batch`](./#val-send_batch). `delay_seconds` delays its delivery, from 0 to 86400\.

Raises `Invalid_argument` when `delay_seconds` is outside 0 to 86400, or when `body` is `Json` with a float that JSON cannot write (`nan` or an infinity).

```ocaml
val send : ?delay_seconds:int -> t -> body -> unit
```
`send queue body` adds one message to the queue. It suspends until the queue accepts it. Call it inside an event handler or a [`Context.wait_until`](./Workero-Context.md#val-wait_until) function. `delay_seconds` delays delivery, from 0 to 86400\.

Raises `Invalid_argument` when `delay_seconds` is outside 0 to 86400\.

raises [`Js_error`](./Workero.md#exception-Js_error) when the runtime rejects the message, for example when it is too large.
```ocaml
val send_batch : ?delay_seconds:int -> t -> message list -> unit
```
`send_batch queue messages` adds the messages in one call. `delay_seconds` applies to the messages that set no delay with [`message`](./#val-message). It suspends until the queue accepts the batch.

Raises `Invalid_argument` when `delay_seconds` is outside 0 to 86400\.

raises [`Js_error`](./Workero.md#exception-Js_error) when the runtime rejects the batch.
```ocaml
module Message : sig ... end
```
A message that a consumer received. Read its body with the function that matches how the producer sent it. Cloudflare gives the consumer the body only, not the content type, so the readers cannot tell a `Text` body from a `Json` string.

```ocaml
module Batch : sig ... end
```
The messages that the runtime delivers in one call of the handler.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```