
# Module `Workero.Trace`

Trace items, the argument of a [`Workero.tail`](./Workero.md#val-tail) handler. A trace item records one invocation of a producer Worker: its event, its console output, its exceptions and its outcome. See [Tail Workers](./tail.md).

```ocaml
type outcome = 
  | Ok
  | Exception
  | Exceeded_cpu
  | Exceeded_memory
  | Script_not_found
  | Canceled
  | Response_stream_disconnected
  | Unknown of string (* "unknown" and any value that a future runtime adds. *)
```
```ocaml
type level = [ 
  | `Debug
  | `Info
  | `Log
  | `Warn
  | `Error
 ]
```
The console method. A level that the runtime adds later reads as ``Log`.

```ocaml
type log = {
  timestamp : float;
  level : level;
  message : Jsonkit.t list;
}
```
One console call. `timestamp` is milliseconds since the Unix epoch. `message` holds the arguments of the call, in JSON form. An argument with no JSON form reads as ``Null`.

```ocaml
type exn_info = {
  timestamp : float;
  name : string;
  message : string;
  stack : string option;
}
```
An uncaught exception of the producer. `timestamp` is milliseconds since the Unix epoch.

```ocaml
module Request : sig ... end
```
The request of a fetch invocation.

```ocaml
type websocket_event = 
  | Ws_message
  | Ws_close of {
    code : int;
    was_clean : bool;
  }
  | Ws_error (* The event that woke a Durable Object with a hibernated WebSocket. *)
```
```ocaml
type event = 
  | Fetch of {
    request : Request.t;
    status : int option;
  } (* status is None when the handler raised. *)
  | Scheduled of {
    cron : string;
    scheduled_time : float;
  } (* scheduled_time is milliseconds since the Unix epoch. *)
  | Queue of {
    queue : string;
    batch_size : int;
  }
  | Alarm of {
    scheduled_time : float;
  } (* A Durable Object alarm. scheduled_time is milliseconds since the Unix epoch. *)
  | Email of {
    mail_from : string;
    rcpt_to : string;
    raw_size : int;
  }
  | Rpc of {
    method_ : string;
  } (* A call of a method of an entrypoint or Durable Object through RPC. *)
  | Tail of {
    consumed : string option list;
  } (* The invocation of a tail Worker. consumed holds the script name of each producer in the batch. *)
  | Hibernatable_websocket of websocket_event
  | Custom (* A custom event, which carries no information. *)
  | Other of Js_of_ocaml.Js.Unsafe.any (* Any other event, as the runtime gives it. *)
```
```ocaml
type t
```
One trace item: the record of one invocation of the producer.

```ocaml
val outcome : t -> outcome
```
```ocaml
val event : t -> event
```
```ocaml
val event_timestamp : t -> float
```
Milliseconds since the Unix epoch.

```ocaml
val script_name : t -> string option
```
`None` when the producer has no name, as in a local `workerd` test.

```ocaml
val logs : t -> log list
```
```ocaml
val exceptions : t -> exn_info list
```
```ocaml
val truncated : t -> bool
```
`true` when the runtime dropped logs or exceptions because the item was too large.

```ocaml
val wall_time : t -> float
```
Milliseconds. The value is `0.` in local `workerd`.

```ocaml
val cpu_time : t -> float
```
Milliseconds. The value is `0.` in local `workerd`.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```
Fields that have no accessor, such as `scriptVersion`, are read from here with [`Decode`](./Workero-Decode.md).

```ocaml
module Stream : sig ... end
```
The events of a streaming tail Worker, see [`Workero.tail_stream`](./Workero.md#val-tail_stream).
