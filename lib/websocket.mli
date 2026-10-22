(** WebSockets served by the Worker, read by pulling events with {!receive}.

    Functions that raise {!Js_error} do so when the runtime throws. [receive]
    suspends like {!Promise.await}. *)

type t
type message = Text of string | Binary of string

type event =
  | Message of message
  | Close of { code : int; reason : string; was_clean : bool }
  | Failed of string  (** The [error] event. A [Close] follows. *)

type pair = { client : t; server : t }

val pair : unit -> pair
(** [new WebSocketPair()]. *)

val accept : t -> unit
(** [accept()] and starts queueing events. Sets [binaryType] to ["arraybuffer"],
    so binary messages arrive as bytes. Call it before any [receive]. *)

val send : t -> message -> unit
(** Raises {!Js_error} when the socket is closed. *)

val receive : t -> event
(** The next event, in arrival order. Suspends while the queue is empty. After
    [Close] it returns the same [Close] again. One fiber at a time may wait: a
    second concurrent [receive] raises [Invalid_argument]. *)

val close : ?code:int -> ?reason:string -> t -> unit

val response : t -> Response.t
(** Status 101 with [webSocket] set; give it the [client] of a [pair]. *)

val upgrade : Context.t -> (t -> unit) -> Response.t
(** [upgrade ctx f] makes a pair, accepts the server end, runs [f server] in its
    own fiber ([Context.wait_until]), and returns the 101 response at once. When
    [f] returns, the socket closes with code 1000 if it is still open. If [f]
    raises, it closes with 1011 and writes the error with [console.error]. *)

val serialize_attachment : t -> Jsonkit.t -> unit
(** Attaches a JSON value, at most 2048 bytes serialised, to a socket that was
    accepted with {!Durable_object.State.accept_websocket}. The value survives
    hibernation. Raises {!Js_error} when the value is too large or the socket
    was not accepted that way. *)

val deserialize_attachment : t -> Jsonkit.t option
(** The value of {!serialize_attachment}, or [None] when there is none. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
