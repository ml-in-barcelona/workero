(** The [ctx] argument of a Worker handler. *)

type t

val wait_until : t -> (unit -> unit) -> unit
(** [wait_until ctx f] runs [f] in its own fiber and keeps the Worker alive
    until [f] returns, after the response is sent. [f] may suspend with
    {!Promise.await}. If [f] raises, the runtime logs the error. The request
    that called [wait_until] and other requests are not affected. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
