
# Module `Trace.Stream`

The events of a streaming tail Worker, see [`Workero.tail_stream`](./Workero.md#val-tail_stream).

```ocaml
type info = 
  | Fetch of {
    method_ : string;
    url : string;
    headers : (string * string) list;
  } (* Headers and URL are redacted by the runtime. *)
  | Jsrpc
  | Scheduled of {
    cron : string;
    scheduled_time : float;
  }
  | Alarm of {
    scheduled_time : float;
  }
  | Queue of {
    queue : string;
    batch_size : int;
  }
  | Email of {
    mail_from : string;
    rcpt_to : string;
    raw_size : int;
  }
  | Trace of {
    traces : string option list;
  } (* The invocation of a tail Worker. traces holds the script name of each producer. *)
  | Hibernatable_websocket of websocket_event
  | Custom
  | Other of Js_of_ocaml.Js.Unsafe.any (* An event info that the runtime adds later. *)
```
What the producer was invoked for. Times are milliseconds since the Unix epoch.

```ocaml
type onset = {
  info : info;
  span_id : string;
  script_name : string option;
  entrypoint : string option;
  execution_model : string;
  attributes : (string * Jsonkit.t) list;
}
```
The first event of an invocation.

```ocaml
type kind = 
  | Onset of onset
  | Outcome of {
    outcome : outcome;
    cpu_time : float;
    wall_time : float;
  } (* The last event of an invocation. Times are milliseconds. *)
  | Span_open of {
    name : string;
    span_id : string;
  }
  | Span_close of {
    outcome : outcome;
  }
  | Diagnostic_channel of {
    channel : string;
    message : Jsonkit.t;
  }
  | Exception of {
    name : string;
    message : string;
    stack : string option;
  }
  | Log of {
    level : level;
    message : Jsonkit.t;
  } (* message is the list of the console arguments, in JSON form. *)
  | Return of {
    status : int option;
  } (* The handler of the producer returned. status is the response status of a fetch. *)
  | Attributes of (string * Jsonkit.t) list
  | Other of Js_of_ocaml.Js.Unsafe.any (* An event that the runtime adds later. *)
```
```ocaml
type t
```
One event of the stream.

```ocaml
val kind : t -> kind
```
```ocaml
val invocation_id : t -> string
```
The same for all events of one invocation.

```ocaml
val trace_id : t -> string
```
```ocaml
val parent_span_id : t -> string option
```
The span that holds the event. `None` for an onset with no inherited span.

```ocaml
val timestamp : t -> float
```
Milliseconds since the Unix epoch.

```ocaml
val sequence : t -> int
```
The position of the event in its invocation, from `0` for the onset.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```