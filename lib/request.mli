type t

val method_ : t -> Method.t

val url : t -> Url.t
(** The request URL.

    @raise Invalid_argument
      when [Js_of_ocaml.Url] cannot parse it. A host containing ["_"] and a URL
      with userinfo, like [http://user:pw@host/], are not parsed. *)

val header : t -> string -> string option
(** [header req name] is the value of header [name], matched without regard to
    letter case. Repeated headers are joined with [", "]. *)

val headers : t -> (string * string) list
(** All headers, with lower case names, sorted by name, as [Headers] iterates
    them. *)

val text : t -> string
(** Reads the whole body as UTF-8 text. Invalid UTF-8 is replaced. *)

val bytes : t -> string
(** Reads the whole body as raw bytes. *)

val cf : t -> Cf.t
(** The Cloudflare properties of the request. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
