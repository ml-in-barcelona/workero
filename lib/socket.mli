(** Outbound TCP sockets, like [connect] from [cloudflare:sockets]. [index.js]
    imports [connect] on every build, so a program needs no setup. See
    {{!page-socket}Sockets}.

    Functions that say "Suspends" suspend like {!Promise.await} and raise
    {!Js_error} when the runtime rejects. *)

type t
(** An open or opening TCP connection. *)

type secure_transport =
  | Off  (** Plain TCP. *)
  | On  (** TLS from the first byte. *)
  | Starttls  (** Plain TCP that {!start_tls} upgrades to TLS. *)

type info = {
  remote_address : string option;  (** The address of the server, if known. *)
  local_address : string option;  (** The local address, if known. *)
}
(** Address information of an open connection. The runtime may leave a field
    out. *)

val connect :
  ?secure_transport:secure_transport ->
  ?allow_half_open:bool ->
  host:string ->
  port:int ->
  unit ->
  t
(** [connect ~host ~port ()] starts a connection and returns at once. A failed
    connection shows in {!opened}, in {!closed} and in the reads and writes.
    Call {!opened} to wait for the connection.

    [secure_transport] is [Off] by default. [allow_half_open] is [false] by
    default: when the server ends its side, the runtime closes the write side
    too. With [true], the write side stays open.

    Raises [Invalid_argument] when [host] is empty or [port] is outside 1 to
    65535, and [Failure] when the runtime has no [cloudflare:sockets] (a program
    run outside a Worker, for example in Node.js).
    @raise Js_error
      when the runtime refuses the address, for example a Cloudflare address, a
      loopback address or port 25. *)

val opened : t -> unit
(** Waits until the connection is up. Suspends. Raises {!Js_error} when the
    connection fails. *)

val info : t -> info
(** Like {!opened}, and gives the {!info} of the connection. Suspends. Raises
    {!Js_error} when the connection fails. *)

val upgraded : t -> bool
(** [true] once {!start_tls} has upgraded the socket to TLS. *)

val closed : t -> unit
(** Waits until the socket is closed. Suspends. Raises {!Js_error} when the
    socket closes with an error. *)

val reader : t -> Stream.Reader.t
(** The read side. {!Stream.Reader.read} gives [None] when the server ends its
    side. Locks the stream: call it once for each socket. Raises {!Js_error} on
    a second call. *)

val writer : t -> Stream.Writer.t
(** The write side. {!Stream.Writer.close} ends it and sends a TCP end of
    stream. Locks the stream: call it once for each socket. Raises {!Js_error}
    on a second call. *)

val close : t -> unit
(** Closes both sides. Suspends. *)

val start_tls : ?expected_server_hostname:string -> t -> t
(** [start_tls socket] upgrades a socket made with [Starttls] and returns the
    secure socket. Release the reader and writer of [socket] before the call,
    and use {!reader} and {!writer} of the result. The old [socket] stops
    working. [expected_server_hostname] replaces the host name that the server
    certificate must match.

    Raises {!Js_error} when [socket] was not made with [Starttls], or when the
    runtime rejects the upgrade. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
