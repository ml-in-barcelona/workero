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

type event = {
  payload : Rpc.value;
      (** The [params] of {!create}; [`Undefined] when there were none. *)
  timestamp : float;
      (** When the instance was created, in milliseconds since the epoch, like
          {!Date.now}. *)
  instance_id : string;
}
(** The event given to the function of {!register}. *)

module Step : sig
  type t
  (** The step object of one run. *)

  type backoff = Constant | Linear | Exponential

  type retries
  (** How to retry a failed step. *)

  val retries :
    ?backoff:backoff -> limit:int -> delay:Duration.t -> unit -> retries
  (** [retries ~limit ~delay ()] retries up to [limit] times, waiting [delay]
      before the first retry. [backoff] defaults to what the runtime defaults
      to, [Exponential].

      Raises [Invalid_argument] when [limit] is not in [0..10000]. *)

  type context = {
    attempt : int;  (** 1 on the first try, 2 on the first retry. *)
  }
  (** What the runtime tells a step callback about the call. *)

  val do_ :
    ?retries:retries ->
    ?timeout:Duration.t ->
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

  val wait_for_event :
    ?timeout:Duration.t -> t -> string -> type_:string -> Rpc.value
  (** [wait_for_event step name ~type_] waits for {!Instance.send_event} with
      the same [type_] and returns its payload. An event sent earlier is kept.
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
  val terminate : t -> unit

  val restart : t -> unit
  (** Starts again from the beginning. *)

  val send_event : t -> type_:string -> Rpc.value -> unit
  (** [send_event i ~type_ payload] delivers an event to {!Step.wait_for_event}.
      The runtime raises {!Js_error} when the instance is not running.

      Raises [Invalid_argument] when [type_] is not valid, as for
      {!Step.wait_for_event}. *)
end

val create : ?id:string -> ?params:Rpc.value -> t -> Instance.t
(** [create workflow] starts an instance. [id] defaults to a generated one;
    [params] is the [payload] of the {!event}. Raises {!Js_error} when [id] is
    in use, and [Invalid_argument] when [id] is longer than 100 characters. *)

type options
(** The arguments of one instance in {!create_batch}. *)

val options : ?id:string -> ?params:Rpc.value -> unit -> options

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
