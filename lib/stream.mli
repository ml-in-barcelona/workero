(** Byte streams: a JavaScript [ReadableStream] and its readers and writers.

    Functions that say "Suspends" suspend like {!Promise.await} and raise
    {!Js_error} when the runtime rejects. *)

type t
(** A JavaScript [ReadableStream] of bytes. *)

module Reader : sig
  type t

  val read : t -> string option
  (** Next chunk, or [None] at the end. Suspends. *)

  val cancel : ?reason:string -> t -> unit
  (** Tells the source to stop. Suspends. *)
end

module Writer : sig
  type t

  val write : t -> string -> unit
  (** Writes one chunk. Suspends until the consumer has room (back-pressure).
      Raises {!Js_error} when the consumer is gone, for example after a client
      disconnect. *)

  val close : t -> unit
  (** Ends the stream. Suspends. *)

  val abort : ?reason:string -> t -> unit
  (** Ends the stream with an error. Suspends. *)
end

val reader : t -> Reader.t
(** Locks the stream. Raises {!Js_error} when it is already locked. *)

val iter : (string -> unit) -> t -> unit
(** [iter f s] calls [f] on every chunk until the end. Suspends. *)

val pipe : unit -> Writer.t * t
(** An identity [TransformStream]: what is written is read from [t]. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
