(** Cloudflare Workflows: durable, multi-step programs.

    A Workflow has two sides. The class side is a function that {!register}
    binds to a name; [workero build] exports it as a [WorkflowEntrypoint], and
    the Workflows engine runs it step by step. The binding side starts and
    controls instances from any Worker, like [env.MY_WORKFLOW.create()] in
    JavaScript. Declare the class in [wrangler.toml]:
    {v
      [[workflows]]
      name = "my-workflow"
      binding = "MY_WORKFLOW"
      class_name = "Greet"
    v}
    [class_name] is the name given to {!register}.

    {2 Replay}

    The engine runs the function again after each sleep, wait, retry or
    eviction. {!Step.do_} returns the stored result of a step that already
    finished, without calling its callback. So code outside the steps runs again
    every time: it must be deterministic. Do not read the clock, random numbers
    or mutable state outside a step; produce the value inside a step and return
    it. Keep no state in OCaml values between steps, as they are lost on replay.
    A step callback runs at least once, so make it idempotent.

    Step results, event payloads and params are {!Rpc.value}s: JSON values and
    also [`Undefined], [`Bytes], [`Date], [`Bigint], [`Map] and [`Set], the
    types that the runtime stores. *)

exception Non_retryable of string
(** Raise it in a {!Step.do_} callback to fail the step without retries. The
    runtime sees a [NonRetryableError] with this message. Raised in the function
    given to {!register}, it fails the instance. *)

module Duration : sig
  type t
  (** A length of time, sent to the runtime in milliseconds. *)

  val ms : int -> t
  (** [ms n], like {!seconds}, {!minutes}, {!hours} and {!days}, is [n] units of
      time. These functions raise [Invalid_argument] for a negative count. *)

  val seconds : int -> t
  val minutes : int -> t
  val hours : int -> t
  val days : int -> t
end

type schedule = { cron : string; scheduled_time : float }
(** The cron trigger that started an instance. [scheduled_time] is in
    milliseconds since the epoch. *)

type event = {
  payload : Rpc.value;
      (** The [params] of {!create}; [`Undefined] when there were none. *)
  timestamp : float;
      (** When the instance was created, in milliseconds since the epoch, like
          {!Date.now}. *)
  instance_id : string;
  workflow_name : string;  (** The name of the Workflow. *)
  schedule : schedule option;
      (** [Some _] for an instance started by a cron [schedules] entry of the
          binding in [wrangler.toml]. *)
}
(** The event given to the function of {!register}. *)

module Step : sig
  type t
  (** The step object of one run. *)

  type backoff = Constant | Linear | Exponential

  type retries
  (** How to retry a failed step. *)

  type config = {
    retries_limit : int option;
        (** The retry limit that applies to the step, if the runtime reports
            one. *)
    backoff : backoff option;
  }
  (** The retry configuration that the runtime reports for a step. It leaves out
      [delay] and [timeout], which the runtime reports as a number or a string.
  *)

  type context = {
    attempt : int;  (** 1 on the first try, 2 on the first retry. *)
    step_name : string;
    step_count : int;
        (** 1 for the first step with this name, 2 for the second. *)
    config : config;
  }
  (** What the runtime tells a step callback about the call. *)

  type delay_context = {
    delay_ctx : context;
    delay_error : string * string;
        (** Name and message of the error that failed the attempt. *)
  }
  (** What the runtime gives to the function of {!retries_with}. *)

  val retries_with :
    ?backoff:backoff -> limit:int -> (delay_context -> Duration.t) -> retries
  (** [retries_with ~limit f] is like {!val-retries}, with the delay before each
      retry computed by [f] from the failed attempt. [f] runs in its own fiber
      and may call {!Promise.await}.

      Raises [Invalid_argument] when [limit] is not in [0..10000]. *)

  val retries :
    ?backoff:backoff -> limit:int -> delay:Duration.t -> unit -> retries
  (** [retries ~limit ~delay ()] retries up to [limit] times, waiting [delay]
      before the first retry. [backoff] defaults to what the runtime defaults
      to, [Exponential].

      Raises [Invalid_argument] when [limit] is not in [0..10000]. *)

  type rollback_context = {
    rollback_ctx : context;  (** The context of the step. *)
    rollback_error : string * string;
        (** Name and message of the error that made the runtime roll back. *)
    rollback_output : Rpc.value;  (** What the step returned. *)
  }

  type rollback
  (** A handler that undoes a step. *)

  val rollback :
    ?retries:retries ->
    ?timeout:Duration.t ->
    (rollback_context -> unit) ->
    rollback
  (** [rollback f] runs [f] to undo a step. The runtime calls it, in reverse
      order of the steps, when the instance fails or when {!Instance.terminate}
      has [~rollback:true]. [retries] and [timeout] apply to the handler. [f]
      runs in its own fiber and may call {!Promise.await}. *)

  val do_ :
    ?retries:retries ->
    ?timeout:Duration.t ->
    ?rollback:rollback ->
    t ->
    string ->
    (context -> Rpc.value) ->
    Rpc.value
  (** [do_ step name f] runs [f] as a step and returns its result. [f] gets the
      {!context} of the attempt. The result is stored and a replay returns it
      without calling [f]. [name] identifies the step, so it must be the same on
      each replay. Without [retries] and [timeout], the runtime defaults apply:
      5 retries, a delay of 10 seconds, exponential backoff, and a timeout of 10
      minutes for each attempt.

      [f] runs in its own fiber and may call {!Promise.await}. An exception
      raised by [f] fails the attempt; {!Non_retryable} stops the retries. When
      the step fails for good, [do_] raises {!Js_error}. Catch it to keep the
      instance running. A step cannot start another step.

      Raises [Invalid_argument] when [name] is longer than 256 characters, or
      when the result has no {!Rpc.value} form. *)

  val sleep : t -> string -> Duration.t -> unit
  (** [sleep step name d] sleeps for [d]. The runtime allows up to 365 days. *)

  val sleep_until : t -> string -> float -> unit
  (** [sleep_until step name at] sleeps until [at], milliseconds since the
      epoch. Use a value computed in a step or taken from the event, so that
      replays agree. *)

  type step_event = {
    event_type : string;
    event_payload : Rpc.value;
    event_timestamp : float;
        (** When the runtime received the event, in milliseconds since the
            epoch. *)
  }
  (** An event that {!Instance.send_event} delivered. *)

  val wait_for_event :
    ?timeout:Duration.t -> t -> string -> type_:string -> step_event
  (** [wait_for_event step name ~type_] waits for {!Instance.send_event} with
      the same [type_] and returns the event. An event sent earlier is kept.
      [timeout] defaults to 24 hours. When it expires, raises {!Js_error}.

      Raises [Invalid_argument] when [type_] is empty, longer than 100
      characters or has a character other than letters, digits, [-] and [_]. *)
end

val register : string -> (Env.t -> event -> Step.t -> Rpc.value) -> unit
(** [register class_name run] binds [run] to the class that [workero build]
    exports under [class_name]. Call it at module initialisation, once per
    class. [run env event step] runs in a fiber and may call {!Promise.await}.
    Its result is the output of the instance, and an uncaught exception fails
    the instance. The runtime creates a new instance of the class for each run.

    Raises [Invalid_argument] when [class_name] is not a valid class name (see
    {!Durable_object.register}), or when it is also the name of a Durable Object
    class, an entrypoint or another Workflow. *)

type t
(** A Workflow binding. *)

val of_env : Env.t -> string -> t
(** [of_env env name] is the Workflow binding [name].

    Raises [Invalid_argument] when [env] has no binding [name], or when the
    binding has no [create], [createBatch] or [get] method. *)

(** The calls suspend like {!Promise.await}. They raise {!Js_error} when the
    runtime rejects, for example for an instance that does not exist. *)
module Instance : sig
  type t
  (** One instance of a Workflow. *)

  type status =
    | Queued
    | Running
    | Paused
    | Errored
    | Terminated
    | Complete
    | Waiting
    | Waiting_for_pause
    | Unknown

  type state = {
    status : status;
    error : (string * string) option;  (** Error name and message. *)
    output : Rpc.value option;
        (** What the function of {!register} returned, once complete. *)
  }

  val id : t -> string

  val status : t -> state
  (** The state now. *)

  val pause : t -> unit
  val resume : t -> unit

  val terminate : ?rollback:bool -> t -> unit
  (** [terminate i] stops the instance. With [~rollback:true] the runtime first
      runs the {!Step.val-rollback} handlers. *)

  type step_kind = Do | Sleep | Wait_for_event

  type restart_from
  (** A step to restart from. *)

  val restart_from : ?count:int -> ?kind:step_kind -> string -> restart_from
  (** [restart_from name] is the step called [name]. [count] picks the nth step
      with that name, from 1 (the default). [kind] picks a {!Step.do_}, a sleep
      or a {!Step.wait_for_event} when names repeat across kinds.

      Raises [Invalid_argument] when [count] is below 1. *)

  val restart : ?from:restart_from -> t -> unit
  (** Starts again from the beginning. With [from], the steps before it keep
      their stored results. The runtime raises {!Js_error} when no step matches
      [from]. *)

  val delete : t -> unit
  (** Deletes the instance and its stored state. A running instance stops. *)

  val send_event : t -> type_:string -> Rpc.value -> unit
  (** [send_event i ~type_ payload] delivers an event to {!Step.wait_for_event}.
      The runtime raises {!Js_error} when the instance is not running.

      Raises [Invalid_argument] when [type_] is not valid, as for
      {!Step.wait_for_event}. *)
end

type retention
(** How long the runtime keeps the state of finished instances. *)

val retention : ?success:Duration.t -> ?error:Duration.t -> unit -> retention
(** [retention ~success ~error ()] keeps a completed instance for [success] and
    a failed one for [error]. What is left out defaults to the binding's
    [default_retention] and then to the maximum of the account. *)

val create :
  ?id:string -> ?params:Rpc.value -> ?retention:retention -> t -> Instance.t
(** [create workflow] starts an instance. [id] defaults to a generated one;
    [params] is the [payload] of the {!type-event}. Raises {!Js_error} when [id]
    is in use, and [Invalid_argument] when [id] is longer than 100 characters.
*)

type options
(** The arguments of one instance in {!create_batch}. *)

val options :
  ?id:string -> ?params:Rpc.value -> ?retention:retention -> unit -> options

type batch_error = {
  index : int;
  id : string option;
  code : int;
  message : string;
}
(** An instance that {!create_batch} did not create, for example for an [id] in
    use. *)

val create_batch : t -> options list -> Instance.t list * batch_error list
(** [create_batch workflow l] starts up to 100 instances at once. It returns the
    instances created and the errors, in the order of [l]. *)

val get : t -> string -> Instance.t
(** [get workflow id] is the instance [id]. Raises {!Js_error} when it does not
    exist. *)

val create_batch_count :
  ?params:Rpc.value ->
  ?retention:retention ->
  t ->
  count:int ->
  Instance.t list * batch_error list
(** [create_batch_count workflow ~count] starts [count] instances with generated
    ids and the same [params] and [retention]. Raises [Invalid_argument] when
    [count] is not in [1..100]. *)

type delete_error = {
  failed_id : string;
  failed_code : int;
  failed_message : string;
}
(** An instance that {!delete_batch} did not delete. *)

val delete_batch : t -> string list -> string list * delete_error list
(** [delete_batch workflow ids] deletes up to 100 instances at once. It returns
    the ids deleted and the errors. A running instance stops without running its
    rollback handlers. Raises [Invalid_argument] when [ids] has no element or
    more than 100. *)
