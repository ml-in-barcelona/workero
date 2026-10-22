
# Module `Queue.Message`

A message that a consumer received. Read its body with the function that matches how the producer sent it. Cloudflare gives the consumer the body only, not the content type, so the readers cannot tell a `Text` body from a `Json` string.

```ocaml
type t
```
```ocaml
val id : t -> string
```
```ocaml
val timestamp : t -> float
```
When the producer sent the message, in milliseconds since the Unix epoch.

```ocaml
val attempts : t -> int
```
How many times the runtime delivered the message, starting at 1\.

```ocaml
val body_json : t -> Jsonkit.t
```
The body as JSON, for a message sent as `Json`. A `Text` body gives a JSON string.

Raises `Invalid_argument` when the body has no JSON form, as in [`JSON.of_js`](./Workero-JSON.md#val-of_js).

```ocaml
val body_text : t -> string
```
The body of a message sent as `Text`.

Raises `Invalid_argument` when the body is not a string.

```ocaml
val body_bytes : t -> string
```
The body of a message sent as `Bytes`, as raw bytes.

Raises `Invalid_argument` when the body is not binary data.

```ocaml
val body_js : t -> Js_of_ocaml.Js.Unsafe.any
```
The body as the runtime delivered it. Use it for a message that another producer sent with the `v8` content type.

```ocaml
val ack : t -> unit
```
Marks the message as delivered, so the runtime does not retry it, even when the handler raises later.

```ocaml
val retry : ?delay_seconds:int -> t -> unit
```
Asks the runtime to deliver the message again, after `delay_seconds` (0 to 86400\) when given.

Raises `Invalid_argument` when `delay_seconds` is outside that range.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```