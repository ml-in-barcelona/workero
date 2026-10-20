(** Cloudflare properties of an incoming request, from [request.cf]. Each
    accessor is [None] when the runtime does not provide the property, for
    example outside Cloudflare's network or in a local test. *)

type t

val country : t -> string option
(** Two-letter ISO 3166-1 country code of the client, such as ["ES"]. *)

val region : t -> string option
(** Name of the client's region. *)

val city : t -> string option

val colo : t -> string option
(** Three-letter IATA code of the data center that handled the request. *)

val timezone : t -> string option
(** IANA time zone of the client, such as ["Europe/Madrid"]. *)

val asn : t -> int option
(** Autonomous system number of the client. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
