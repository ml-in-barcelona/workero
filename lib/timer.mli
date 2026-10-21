(** JavaScript timers: [setTimeout], [setInterval] and their [clear] functions.
    Delays are in milliseconds. Call them only from inside a handler or a
    {!Context.wait_until} function; the Workers runtime refuses timers at
    startup. *)

type timeout
(** A pending [setTimeout]. *)

type interval
(** A running [setInterval]. *)

val sleep : int -> unit Promise.t
(** [sleep ms] resolves after [ms] milliseconds. Use [Promise.await (sleep ms)]
    to wait in direct style. *)

val set_timeout : (unit -> unit) -> int -> timeout
(** [set_timeout f ms] calls [f] once after [ms] milliseconds, like
    [setTimeout(f, ms)]. [f] runs outside the handler, so it cannot call
    {!Promise.await}. An exception raised by [f] is an uncaught JavaScript
    error. *)

val clear_timeout : timeout -> unit
(** [clearTimeout]. Clearing a timeout that already ran does nothing. *)

val set_interval : (unit -> unit) -> int -> interval
(** [set_interval f ms] calls [f] every [ms] milliseconds until
    {!clear_interval}, like [setInterval(f, ms)]. [f] follows the rules of
    {!set_timeout}. *)

val clear_interval : interval -> unit
(** [clearInterval]. *)
