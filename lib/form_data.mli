(** Parsed [multipart/form-data] and [application/x-www-form-urlencoded] bodies:
    a JavaScript [FormData]. Get one from {!Request.form_data}.

    Functions that say "Suspends" suspend like {!Promise.await} and raise
    {!Js_error} when the runtime rejects. *)

type t
type file
type value = Text of string | File of file

val get : t -> string -> value option
(** First entry with this name. *)

val get_all : t -> string -> value list

val to_list : t -> (string * value) list
(** Entries in the order sent, duplicates kept. *)

val file_name : file -> string

val file_type : file -> string
(** The part's [content-type]; [""] when absent. *)

val file_size : file -> int

val file_bytes : file -> string
(** Reads the whole file. Suspends. *)

val file_stream : file -> Stream.t
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
