(** Write a Cloudflare Worker in OCaml, compiled with wasm_of_ocaml. *)

type js = Js_of_ocaml.Js.Unsafe.any
(** A raw JavaScript value. *)

exception Js_error of string
(** Raised by {!await} when the awaited JavaScript Promise rejects. The payload
    is the rejection reason as a string. *)

val await : js -> js
(** [await promise] suspends the current request until the JavaScript Promise
    [promise] settles. It returns the resolved value or raises {!Js_error}. Call
    it only from inside a handler given to {!fetch}. *)

module URL : sig
  (** A URL is a {!Uri.t}: the whole [Uri] API is available, for example
      {!Uri.path}, {!Uri.host}, {!Uri.query} and {!Uri.get_query_param}. *)
  include module type of struct
    include Uri
  end

  val query : t -> string -> string option
  (** [query url name] is the first value of the query parameter [name], decoded
      from percent-encoding, or [None] when the parameter is absent. *)
end

module Request : sig
  type t

  val method_ : t -> string

  val url : t -> URL.t
  (** The request URL, parsed with [Uri.of_string]. *)

  val header : t -> string -> string option

  val text : t -> string
  (** Reads the whole body. *)
end

module Response : sig
  type t

  val text : ?status:int -> ?headers:(string * string) list -> string -> t
end

module Env : sig
  type t

  val var : t -> string -> string option
  (** A string variable or secret. *)
end

val fetch : (Request.t -> Env.t -> Response.t) -> unit
(** Registers the request handler. An exception raised by the handler rejects
    the response Promise, and the runtime answers with status 500. *)
