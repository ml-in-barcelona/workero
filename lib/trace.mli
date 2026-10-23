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

type websocket_event =
  | Ws_message
  | Ws_close of { code : int; was_clean : bool }
  | Ws_error
      (** The event that woke a Durable Object with a hibernated WebSocket. *)

type event =
  | Fetch of { request : Request.t; status : int option }
      (** [status] is [None] when the handler raised. *)
  | Scheduled of { cron : string; scheduled_time : float }
      (** [scheduled_time] is milliseconds since the Unix epoch. *)
  | Queue of { queue : string; batch_size : int }
  | Alarm of { scheduled_time : float }
      (** A Durable Object alarm. [scheduled_time] is milliseconds since the
          Unix epoch. *)
  | Email of { mail_from : string; rcpt_to : string; raw_size : int }
  | Rpc of { method_ : string }
      (** A call of a method of an entrypoint or Durable Object through RPC. *)
  | Tail of { consumed : string option list }
      (** The invocation of a tail Worker. [consumed] holds the script name of
          each producer in the batch. *)
  | Hibernatable_websocket of websocket_event
  | Custom  (** A custom event, which carries no information. *)
  | Other of Js_of_ocaml.Js.Unsafe.any
      (** Any other event, as the runtime gives it. *)

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

(** The events of a streaming tail Worker, see {!Workero.tail_stream}. *)
module Stream : sig
  (** What the producer was invoked for. Times are milliseconds since the Unix
      epoch. *)
  type info =
    | Fetch of {
        method_ : string;
        url : string;
        headers : (string * string) list;
      }  (** Headers and URL are redacted by the runtime. *)
    | Jsrpc
    | Scheduled of { cron : string; scheduled_time : float }
    | Alarm of { scheduled_time : float }
    | Queue of { queue : string; batch_size : int }
    | Email of { mail_from : string; rcpt_to : string; raw_size : int }
    | Trace of { traces : string option list }
        (** The invocation of a tail Worker. [traces] holds the script name of
            each producer. *)
    | Hibernatable_websocket of websocket_event
    | Custom
    | Other of Js_of_ocaml.Js.Unsafe.any
        (** An event info that the runtime adds later. *)

  type onset = {
    info : info;
    span_id : string;
    script_name : string option;
    entrypoint : string option;
    execution_model : string;
    attributes : (string * Jsonkit.t) list;
  }
  (** The first event of an invocation. *)

  type kind =
    | Onset of onset
    | Outcome of { outcome : outcome; cpu_time : float; wall_time : float }
        (** The last event of an invocation. Times are milliseconds. *)
    | Span_open of { name : string; span_id : string }
    | Span_close of { outcome : outcome }
    | Diagnostic_channel of { channel : string; message : Jsonkit.t }
    | Exception of { name : string; message : string; stack : string option }
    | Log of { level : level; message : Jsonkit.t }
        (** [message] is the list of the console arguments, in JSON form. *)
    | Return of { status : int option }
        (** The handler of the producer returned. [status] is the response
            status of a fetch. *)
    | Attributes of (string * Jsonkit.t) list
    | Other of Js_of_ocaml.Js.Unsafe.any
        (** An event that the runtime adds later. *)

  type t
  (** One event of the stream. *)

  val kind : t -> kind

  val invocation_id : t -> string
  (** The same for all events of one invocation. *)

  val trace_id : t -> string

  val parent_span_id : t -> string option
  (** The span that holds the event. [None] for an onset with no inherited span.
  *)

  val timestamp : t -> float
  (** Milliseconds since the Unix epoch. *)

  val sequence : t -> int
  (** The position of the event in its invocation, from [0] for the onset. *)

  val of_js : Js_of_ocaml.Js.Unsafe.any -> t
  val to_js : t -> Js_of_ocaml.Js.Unsafe.any
end
