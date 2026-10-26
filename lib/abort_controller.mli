(** [AbortController]: aborts an {!Abort_signal}. *)

type t

val create : unit -> t

val signal : t -> Abort_signal.t
(** The signal to pass to the work that [abort] cancels. *)

val abort : ?reason:[ `Abort of string | `Timeout of string ] -> t -> unit
(** [abort c] aborts the signal of [c]. [`Abort msg] gives an [AbortError] and
    [`Timeout msg] a [TimeoutError] with that message. Listeners registered with
    {!Abort_signal.on_abort} run in their own fibers; [abort] does not wait for
    them. Aborting twice does nothing. *)
