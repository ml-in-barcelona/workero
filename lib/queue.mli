(** Cloudflare Queues. A {!t} sends messages through a producer binding in
    [wrangler.toml] ([[[queues.producers]]]). A {!Workero.queue} handler
    consumes batches from a queue configured under [[[queues.consumers]]], not
    through a producer binding. See {{!page-queue}Queue} for a complete Worker.

    Under [open Workero], this module hides [Stdlib.Queue]. Write [Stdlib.Queue]
    to reach the standard one. *)

type t

val of_env : Env.t -> string -> t
(** [of_env env name] is the queue producer bound as [name].

    Raises [Invalid_argument] when [env] has no binding [name], or when the
    binding has no [send] and [sendBatch] methods. *)

(** The body of a message. Each constructor sets the content type, so a body and
    its content type cannot disagree. *)
type body =
  | Json of Jsonkit.t  (** Content type [json]. *)
  | Text of string  (** Content type [text]. *)
  | Bytes of string  (** Content type [bytes]: raw bytes. *)

type message
(** A message to send in a batch, made by {!val:message}. *)

val message : ?delay_seconds:int -> body -> message
(** [message body] is a message for {!send_batch}. [delay_seconds] delays its
    delivery, from 0 to 86400.

    Raises [Invalid_argument] when [delay_seconds] is outside 0 to 86400, or
    when [body] is [Json] with a float that JSON cannot write ([nan] or an
    infinity). *)

val send : ?delay_seconds:int -> t -> body -> unit
(** [send queue body] adds one message to the queue. It suspends until the queue
    accepts it. Call it inside an event handler or a {!Context.wait_until}
    function. [delay_seconds] delays delivery, from 0 to 86400.

    Raises [Invalid_argument] when [delay_seconds] is outside 0 to 86400.
    @raise Js_error
      when the runtime rejects the message, for example when it is too large. *)

val send_batch : ?delay_seconds:int -> t -> message list -> unit
(** [send_batch queue messages] adds the messages in one call. [delay_seconds]
    applies to the messages that set no delay with {!val:message}. It suspends
    until the queue accepts the batch.

    Raises [Invalid_argument] when [delay_seconds] is outside 0 to 86400.
    @raise Js_error when the runtime rejects the batch. *)

(** A message that a consumer received. Read its body with the function that
    matches how the producer sent it. Cloudflare gives the consumer the body
    only, not the content type, so the readers cannot tell a [Text] body from a
    [Json] string. *)
module Message : sig
  type t

  val id : t -> string

  val timestamp : t -> float
  (** When the producer sent the message, in milliseconds since the Unix epoch.
  *)

  val attempts : t -> int
  (** How many times the runtime delivered the message, starting at 1. *)

  val body_json : t -> Jsonkit.t
  (** The body as JSON, for a message sent as [Json]. A [Text] body gives a JSON
      string.

      The consumer receives no content-type field. Raises [Invalid_argument]
      when the body has no JSON form, as in {!JSON.of_js}. *)

  val body_text : t -> string
  (** The body of a message sent as [Text].

      Raises [Invalid_argument] when the body is not a string. *)

  val body_bytes : t -> string
  (** The body of a message sent as [Bytes], as raw bytes.

      Raises [Invalid_argument] when the body is not binary data. *)

  val body_js : t -> Js_of_ocaml.Js.Unsafe.any
  (** The body as the runtime delivered it. Use it for a message that another
      producer sent with the [v8] content type. *)

  val ack : t -> unit
  (** Mark the message as delivered after processing succeeds. The runtime does
      not retry it even if the handler raises later. *)

  val retry : ?delay_seconds:int -> t -> unit
  (** Asks the runtime to deliver the message again, after [delay_seconds] (0 to
      86400) when given.

      Raises [Invalid_argument] when [delay_seconds] is outside that range. *)

  val of_js : Js_of_ocaml.Js.Unsafe.any -> t
  val to_js : t -> Js_of_ocaml.Js.Unsafe.any
end

(** The messages that the runtime delivers in one call of the handler. *)
module Batch : sig
  type t

  val queue : t -> string
  (** The name of the queue. *)

  val messages : t -> Message.t list
  (** The messages, in the order of delivery. If the handler returns without
      explicit acknowledgement or retry, the remaining messages count as
      delivered. If it raises, the runtime retries messages not already
      acknowledged, subject to the queue's retry configuration. *)

  val ack_all : t -> unit
  (** Marks every message as delivered. *)

  val retry_all : ?delay_seconds:int -> t -> unit
  (** Asks the runtime to deliver every message again, after [delay_seconds] (0
      to 86400) when given.

      Raises [Invalid_argument] when [delay_seconds] is outside that range. *)

  val of_js : Js_of_ocaml.Js.Unsafe.any -> t
  val to_js : t -> Js_of_ocaml.Js.Unsafe.any
end

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
