(** [AbortSignal]: tells running work to stop.

    An abort cancels the I/O, not the fiber. A function that starts cancelable
    I/O takes a [?signal], such as {!Workero.fetch}. When the signal aborts, the
    runtime rejects the I/O, and the call that awaits it raises
    {!Workero.Js_error}. Use {!is_abort} to tell that error from others. An
    abort cannot interrupt OCaml code that computes or awaits something else:
    test {!aborted} between steps, or race the await against {!to_promise}. *)

type t

val aborted : t -> bool

val reason : t -> Promise.error option
(** The abort reason; [None] while the signal has not aborted. JavaScript allows
    any value, so the type is {!Promise.error}. *)

val throw_if_aborted : t -> unit
(** Raises {!Workero.Js_error} with the reason when the signal has aborted, like
    [signal.throwIfAborted()]. *)

val timeout : int -> t
(** [timeout ms] is [AbortSignal.timeout ms]. It aborts after [ms] milliseconds
    with a [TimeoutError]. The timer starts at once, so call it only from inside
    a handler or a {!Context.wait_until} function. *)

val any : t list -> t
(** [AbortSignal.any]: aborts when the first of the signals aborts, with the
    reason of that signal. *)

val aborted_now : ?reason:string -> unit -> t
(** [AbortSignal.abort()]: a signal that has already aborted. A [reason] becomes
    an [AbortError] with that message. Without it the reason is the default
    [AbortError]. *)

val on_abort : t -> (unit -> unit) -> unit
(** [on_abort s f] runs [f] once, in its own fiber, when [s] aborts, or at once
    when [s] has already aborted. [f] may call {!Promise.await}. An exception
    that [f] raises is written to [console.error]. *)

val to_promise : t -> 'a Promise.t
(** A promise that never resolves and rejects with the reason when the signal
    aborts. Use it in {!Promise.race} to stop waiting for any promise:
    [Promise.race [p; Abort_signal.to_promise s]]. The work behind [p] keeps
    running. *)

val is_abort : exn -> bool
(** [true] for a {!Workero.Js_error} whose reason is a JavaScript [Error] named
    [AbortError] or [TimeoutError]. A [Js_error] with another reason, such as
    the one from {!Stream.Writer.write} after a client disconnect, gives
    [false]. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
