(** The [controller] argument of a Worker [scheduled] handler. *)

type t

val cron : t -> string
(** The cron expression that fired, for example ["*/5 * * * *"]. *)

val scheduled_time : t -> float
(** The time the event was scheduled for, in milliseconds since the Unix epoch.
*)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
