(** An absolute [http] or [https] URL, parsed by the JavaScript [URL]. Paths and
    query arguments are percent-decoded. In a query, [+] decodes to a space, as
    in WHATWG [URLSearchParams]. *)

type t

val of_string : string -> t option
(** [None] when the string is not an [http] or [https] URL. *)

val make : Js_of_ocaml.Js.Unsafe.any -> t option
(** [make v] builds a URL from a JavaScript value, such as a URL string, with
    [new URL(v)]. [None] when it is not an [http] or [https] URL. *)

val to_string : t -> string
val scheme : t -> string

val host : t -> string
(** The host name, without port. *)

val port : t -> int
(** The port, or 80 or 443 when the URL has none. *)

val path : t -> string
(** The decoded path, starting with ["/"]. The query string and fragment are not
    part of it. A path that [decodeURIComponent] rejects is returned undecoded.
    That is a malformed escape, such as ["%zz"], or an escape that is not valid
    UTF-8, such as ["%FF"]. *)

val pathname : t -> string
(** The raw path as the JavaScript [pathname]: percent-encoded, so ["%2F"] stays
    ["%2F"]. *)

val search : t -> string
(** The query string with its ["?"], or [""] when there is none. It is not
    decoded. *)

val hash : t -> string
(** The fragment with its ["#"], or [""] when there is none. *)

val origin : t -> string
(** The scheme, host and port, such as ["https://a.test:8443"]. The port is left
    out when it is the default. *)

val query : t -> string -> string option
(** [query url name] is the first decoded value of [name]. *)

val query_all : t -> string -> string list
(** All decoded values of [name], in order. *)

val query_args : t -> (string * string) list
(** All decoded [(name, value)] pairs, in order. *)
