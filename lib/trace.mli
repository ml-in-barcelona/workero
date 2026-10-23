(** Trace items, the argument of a {!Workero.tail} handler. A trace item records
    one invocation of a producer Worker: its event, its console output, its
    exceptions and its outcome. See {{!page-tail}Tail Workers}. *)

type outcome =
  | Ok
  | Exception
  | Exceeded_cpu
  | Exceeded_memory
  | Script_not_found
  | Canceled
  | Response_stream_disconnected
  | Unknown of string
      (** ["unknown"] and any value that a future runtime adds. *)

type level = [ `Debug | `Info | `Log | `Warn | `Error ]
(** The console method. A level that the runtime adds later reads as [`Log]. *)

type log = { timestamp : float; level : level; message : Jsonkit.t list }
(** One console call. [timestamp] is milliseconds since the Unix epoch.
    [message] holds the arguments of the call, in JSON form. An argument with no
    JSON form reads as [`Null]. *)

type exn_info = {
  timestamp : float;
  name : string;
  message : string;
  stack : string option;
}
(** An uncaught exception of the producer. [timestamp] is milliseconds since the
    Unix epoch. *)

(** The request of a fetch invocation. *)
module Request : sig
  type t

  val url : t -> string
  (** Redacted by default; see {!unredacted}. A string, not {!Workero.URL.t}: a
      redacted URL may not parse. *)

  val method_ : t -> string

  val headers : t -> (string * string) list
  (** Redacted by default; see {!unredacted}. *)

  val cf : t -> Cf.t
  (** The tail copy of [request.cf]. It has fewer properties than the request
      the producer saw, so most accessors give [None]. *)

  val unredacted : t -> t
  (** The request with the raw URL and headers, like [getUnredacted()]. *)
end

type event =
  | Fetch of { request : Request.t; status : int option }
      (** [status] is [None] when the handler raised. *)
  | Scheduled of { cron : string; scheduled_time : float }
      (** [scheduled_time] is milliseconds since the Unix epoch. *)
  | Queue of { queue : string; batch_size : int }
  | Other of Js_of_ocaml.Js.Unsafe.any
      (** Any other event, such as an alarm or an email, as the runtime gives
          it. *)

type t
(** One trace item: the record of one invocation of the producer. *)

val outcome : t -> outcome
val event : t -> event

val event_timestamp : t -> float
(** Milliseconds since the Unix epoch. *)

val script_name : t -> string option
(** [None] when the producer has no name, as in a local [workerd] test. *)

val logs : t -> log list
val exceptions : t -> exn_info list

val truncated : t -> bool
(** [true] when the runtime dropped logs or exceptions because the item was too
    large. *)

val wall_time : t -> float
(** Milliseconds. The value is [0.] in local [workerd]. *)

val cpu_time : t -> float
(** Milliseconds. The value is [0.] in local [workerd]. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t

val to_js : t -> Js_of_ocaml.Js.Unsafe.any
(** Fields that have no accessor, such as [scriptVersion], are read from here
    with {!Decode}. *)
