(** An absolute [http] or [https] URL, parsed by [Js_of_ocaml.Url]. Paths and
    query arguments are percent-decoded. In a query, [+] decodes to a space, as
    in WHATWG [URLSearchParams]. *)

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
(** The decoded path, starting with ["/"]. The query string and fragment are not
    part of it. *)

val query : t -> string -> string option
(** [query url name] is the first decoded value of [name]. *)

val query_all : t -> string -> string list
(** All decoded values of [name], in order. *)

val query_args : t -> (string * string) list
(** All decoded [(name, value)] pairs, in order. *)
