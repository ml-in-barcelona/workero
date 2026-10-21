
# Module `Queue.Batch`

The messages that the runtime delivers in one call of the handler.

```ocaml
type t
```
```ocaml
val queue : t -> string
```
The name of the queue.

```ocaml
val messages : t -> Message.t list
```
The messages, in the order of delivery.

```ocaml
val ack_all : t -> unit
```
Marks every message as delivered.

```ocaml
val retry_all : ?delay_seconds:int -> t -> unit
```
Asks the runtime to deliver every message again, after `delay_seconds` (0 to 86400\) when given.

Raises `Invalid_argument` when `delay_seconds` is outside that range.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```