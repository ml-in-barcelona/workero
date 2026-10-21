(** The [env] argument of a Worker handler: its variables, secrets and bindings.
*)

type t

val var : t -> string -> string option
(** A string variable or secret. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
