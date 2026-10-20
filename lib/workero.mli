(** Write Cloudflare Workers in OCaml (via wasm_of_ocaml) *)

type js = Js_of_ocaml.Js.Unsafe.any
(** A raw JavaScript value. *)

exception Js_error of string
(** Raised by {!Promise.await} when the awaited JavaScript Promise rejects. The
    payload is the rejection reason converted with JavaScript [String]. *)

module Promise : sig
  (** A JavaScript [Promise], bound directly. *)

  type 'a t

  val make : (resolve:('a -> unit) -> reject:(string -> unit) -> unit) -> 'a t
  (** [make executor] is [new Promise(executor)]. [reject msg] rejects with a
      JavaScript [Error] whose message is [msg]. *)

  val resolve : 'a -> 'a t
  (** [Promise.resolve]. *)

  val reject : string -> 'a t
  (** [Promise.reject (new Error msg)]. *)

  val await : 'a t -> 'a
  (** [await p] suspends the current request until [p] settles. It returns the
      resolved value or raises {!Js_error}. Call it only from inside a handler
      given to {!fetch}. *)

  val of_js : js -> 'a t
  (** Views a raw JavaScript Promise. The caller states the type of the resolved
      value: a JavaScript string must be typed
      [Js_of_ocaml.Js.js_string Js_of_ocaml.Js.t], not [string]. *)

  val to_js : 'a t -> js
end

module URL : sig
  (** An absolute [http] or [https] URL, parsed by [Js_of_ocaml.Url]. Paths and
      query arguments are percent-decoded. In a query, [+] decodes to a space,
      as in WHATWG [URLSearchParams]. *)

  type t

  val of_string : string -> t option
  (** [None] when the string is not an [http] or [https] URL. *)

  val to_string : t -> string
  val scheme : t -> string

  val host : t -> string
  (** The host name, without port. *)

  val port : t -> int
  (** The port, or 80 or 443 when the URL has none. *)

  val path : t -> string
  (** The decoded path, starting with ["/"]. The query string and fragment are
      not part of it. *)

  val query : t -> string -> string option
  (** [query url name] is the first decoded value of [name]. *)

  val query_all : t -> string -> string list
  (** All decoded values of [name], in order. *)

  val query_args : t -> (string * string) list
  (** All decoded [(name, value)] pairs, in order. *)
end

module Request : sig
  type t

  val method_ : t -> string

  val url : t -> URL.t
  (** The request URL. *)

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
