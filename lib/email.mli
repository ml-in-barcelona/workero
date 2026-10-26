(** Email Routing. The handler that {!Workero.email} registers receives a {!t}:
    a message that Cloudflare Email Routing delivered to the Worker. The handler
    can read the message, forward it, reply to it or reject it.

    Functions that say "Suspends" suspend like {!Promise.await} and raise
    {!Js_error} when the runtime rejects. *)

type t
(** A [ForwardableEmailMessage]. *)

val from : t -> string
(** The envelope sender ([MAIL FROM]). It can differ from the [From] header. *)

val to_ : t -> string
(** The envelope recipient ([RCPT TO]). *)

val header : t -> string -> string option
(** [header message name] is the value of header [name] of the message, matched
    without regard to letter case. Repeated headers are joined with [", "]. *)

val header_all : t -> string -> string list
(** Every value of a header; see {!Request.header_all}. *)

val headers : t -> (string * string) list
(** All headers, with lower case names, sorted by name, as [Headers] iterates
    them. *)

val raw_size : t -> int
(** The size of the raw message in bytes. It is known before the body is read.
*)

val raw : t -> Stream.t
(** The raw message (headers and body, as sent) as a stream. The stream can be
    read once. Use it to read a large message in chunks instead of holding it in
    memory with {!raw_bytes}. *)

val raw_text : t -> string
(** Reads the whole raw message as UTF-8 text. Invalid UTF-8 is replaced.
    Suspends. Raises {!Js_error} when the raw message was read before. *)

val raw_bytes : t -> string
(** Reads the whole raw message as raw bytes. The bytes are copied into the
    memory of the program, so a large message needs that much memory. Suspends.
    Raises {!Js_error} when the raw message was read before. *)

val set_reject : t -> string -> unit
(** [set_reject message reason] rejects the message with a permanent SMTP error.
    The sender gets [reason]. Call it instead of {!forward} or {!reply}. *)

val forward : ?headers:(string * string) list -> t -> string -> unit
(** [forward message address] forwards the message to [address], which must be a
    verified destination address of the account. [headers] adds headers to the
    forwarded message; the runtime accepts only names that start with ["X-"].
    Suspends. *)

val reply :
  t ->
  from:string ->
  to_:string ->
  [ `Text of string | `Stream of Stream.t ] ->
  unit
(** [reply message ~from ~to_ raw] sends [raw], a complete message with headers,
    as a reply to [message]. [from] must be an address of the Worker's domain
    and [to_] the sender. [raw] needs a [Message-ID] header and an [In-Reply-To]
    header that holds the [Message-ID] of [message]. Give it as [`Text] or, for
    a large message or one built in pieces, as a [`Stream]. The runtime reads
    the stream, so do not read it yourself. Suspends.

    @raise Js_error
      when the runtime rejects the reply, or when the runtime has no
      [cloudflare:email] module (workerd). *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
