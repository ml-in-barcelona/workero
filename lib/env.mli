(** The [env] argument of a Worker handler holds bindings: variables, secrets
    and configured resources. *)

type t

val var : t -> string -> string option
(** [var env name] returns [Some value] for a string variable or secret. It
    returns [None] when [name] is missing or its value is not a string. This
    lookup does not suspend. Use a resource module's [of_env] for objects. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
