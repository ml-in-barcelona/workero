(** An HTTP request method. *)

type t = GET | HEAD | POST | PUT | DELETE | PATCH | OPTIONS | Other of string

val of_string : string -> t
(** Parses a method name. Names are case-sensitive, as in HTTP, and the runtime
    gives the standard methods in upper case. Any other name becomes
    [Other name]. [Other "GET"] is never produced. *)

val to_string : t -> string
(** The method name; the payload for [Other]. *)
