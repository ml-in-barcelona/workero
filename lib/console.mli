(** The global [console]. Each call writes one entry to the Workers logs, with
    its level. Unlike [print_string], it needs no flush. *)

val log : string -> unit
val info : string -> unit
val warn : string -> unit
val error : string -> unit
val debug : string -> unit
