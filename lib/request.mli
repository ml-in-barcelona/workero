type t

val method_ : t -> Method.t

val url : t -> Url.t
(** The request URL.

    Raises [Invalid_argument] when it is not an [http] or [https] URL. *)

val path : t -> string
(** The raw path as sent, percent-encoded, starting with ["/"]. ["%2F"] stays
    ["%2F"]. *)

val query_string : t -> string
(** The raw query without the ["?"]; [""] when there is none. *)

val header : t -> string -> string option
(** [header req name] is the value of header [name], matched without regard to
    letter case. Repeated headers are joined with [", "]. Use {!header_all} for
    [cookie] lists and [set-cookie]. *)

val header_all : t -> string -> string list
(** Every value of a header; one entry per [set-cookie], one joined entry for
    other names. *)

val headers : t -> (string * string) list
(** All headers, with lower case names, sorted by name, as [Headers] iterates
    them. *)

val text : t -> string
(** Reads the whole body as UTF-8 text. Invalid UTF-8 is replaced. *)

val bytes : t -> string
(** Reads the whole body as raw bytes. *)

val body : t -> Stream.t option
(** The body as a stream; [None] when the request has none (GET, HEAD). *)

val form_data : t -> Form_data.t
(** Parses a multipart or urlencoded body with the platform parser. Suspends
    like {!Promise.await}. Raises {!Js_error} for another content type. *)

val clone : t -> t
(** [request.clone()]; both copies can read the body. *)

val cf : t -> Cf.t
(** The Cloudflare properties of the request. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
