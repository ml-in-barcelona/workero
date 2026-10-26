module Js = Js_of_ocaml.Js
open Internal

type outcome =
  | Ok
  | Exception
  | Exceeded_cpu
  | Exceeded_memory
  | Script_not_found
  | Canceled
  | Response_stream_disconnected
  | Unknown of string

type level = [ `Debug | `Info | `Log | `Warn | `Error ]
type log = { timestamp : float; level : level; message : Jsonkit.t list }

type exn_info = {
  timestamp : float;
  name : string;
  message : string;
  stack : string option;
}

let number v =
  if typeof v = "number" then Js.float_of_number (Js.Unsafe.coerce v) else 0.

let get_number o name = number (Js.Unsafe.get o name)
let text v = Js.to_string (Js.Unsafe.coerce (call (global "String") [| v |]))
let is_present v = not (is_nullish v || typeof v = "undefined")
let list_of_array v = if is_present v then Decode.(list js) v else []

module Request = struct
  type t = js

  let url r = Option.value (get_string r "url") ~default:""
  let method_ r = Option.value (get_string r "method") ~default:""

  let headers r =
    let h = Js.Unsafe.get r "headers" in
    if not (is_present h) then []
    else
      let entries : js = meth (global "Object") "entries" [| h |] in
      List.map
        (fun pair -> (text (Js.Unsafe.get pair 0), text (Js.Unsafe.get pair 1)))
        (Decode.(list js) entries)

  let cf r =
    let cf = Js.Unsafe.get r "cf" in
    Cf.of_js (if is_present cf then cf else Js.Unsafe.obj [||])

  let unredacted r = meth r "getUnredacted" [||]
end

type websocket_event =
  | Ws_message
  | Ws_close of { code : int; was_clean : bool }
  | Ws_error

type event =
  | Fetch of { request : Request.t; status : int option }
  | Scheduled of { cron : string; scheduled_time : float }
  | Queue of { queue : string; batch_size : int }
  | Alarm of { scheduled_time : float }
  | Email of { mail_from : string; rcpt_to : string; raw_size : int }
  | Rpc of { method_ : string }
  | Tail of { consumed : string option list }
  | Hibernatable_websocket of websocket_event
  | Custom
  | Other of js

let time v =
  if not (is_present v) then 0.
  else if typeof v = "number" then number v
  else number (meth v "getTime" [||])

let websocket_event e =
  let kind = Option.value (get_string e "webSocketEventType") ~default:"" in
  match kind with
  | "close" ->
      Ws_close
        {
          code = Option.value (get_int e "code") ~default:0;
          was_clean =
            (let v = Js.Unsafe.get e "wasClean" in
             typeof v = "boolean" && Js.to_bool (Js.Unsafe.coerce v));
        }
  | "error" -> Ws_error
  | _ -> Ws_message

type t = js

let event t =
  let e = Js.Unsafe.get t "event" in
  if not (is_present e) then Other e
  else
    let request = Js.Unsafe.get e "request" in
    if is_present request then
      let response = Js.Unsafe.get e "response" in
      let status =
        if is_present response then get_int response "status" else None
      in
      Fetch { request; status }
    else if typeof (Js.Unsafe.get e "cron") = "string" then
      Scheduled
        {
          cron = Option.value (get_string e "cron") ~default:"";
          scheduled_time = get_number e "scheduledTime";
        }
    else if typeof (Js.Unsafe.get e "queue") = "string" then
      Queue
        {
          queue = Option.value (get_string e "queue") ~default:"";
          batch_size = Option.value (get_int e "batchSize") ~default:0;
        }
    else if typeof (Js.Unsafe.get e "rpcMethod") = "string" then
      Rpc { method_ = Option.value (get_string e "rpcMethod") ~default:"" }
    else if typeof (Js.Unsafe.get e "mailFrom") = "string" then
      Email
        {
          mail_from = Option.value (get_string e "mailFrom") ~default:"";
          rcpt_to = Option.value (get_string e "rcptTo") ~default:"";
          raw_size = Option.value (get_int e "rawSize") ~default:0;
        }
    else if is_present (Js.Unsafe.get e "consumedEvents") then
      Tail
        {
          consumed =
            List.map
              (fun item -> get_string item "scriptName")
              (list_of_array (Js.Unsafe.get e "consumedEvents"));
        }
    else if is_present (Js.Unsafe.get e "getWebSocketEvent") then
      Hibernatable_websocket
        (websocket_event (Js.Unsafe.get e "getWebSocketEvent"))
    else if is_present (Js.Unsafe.get e "scheduledTime") then
      Alarm { scheduled_time = time (Js.Unsafe.get e "scheduledTime") }
    else if list_of_array (meth (global "Object") "keys" [| e |]) = [] then
      Custom
    else Other e

let event_timestamp t = get_number t "eventTimestamp"
let script_name t = get_string t "scriptName"

let outcome_of_string = function
  | Some "ok" -> Ok
  | Some "exception" -> Exception
  | Some "exceededCpu" -> Exceeded_cpu
  | Some "exceededMemory" -> Exceeded_memory
  | Some "scriptNotFound" -> Script_not_found
  | Some "canceled" -> Canceled
  | Some "responseStreamDisconnected" -> Response_stream_disconnected
  | Some other -> Unknown other
  | None -> Unknown "unknown"

let outcome t = outcome_of_string (get_string t "outcome")

let level_of_string = function
  | "debug" -> `Debug
  | "info" -> `Info
  | "warn" -> `Warn
  | "error" -> `Error
  | _ -> `Log

let json_arg v = try Json.of_js v with Invalid_argument _ -> `Null

let logs t =
  List.map
    (fun l ->
      {
        timestamp = get_number l "timestamp";
        level =
          level_of_string (Option.value (get_string l "level") ~default:"");
        message = List.map json_arg (list_of_array (Js.Unsafe.get l "message"));
      })
    (list_of_array (Js.Unsafe.get t "logs"))

let exceptions t =
  List.map
    (fun e ->
      let message = Js.Unsafe.get e "message" in
      {
        timestamp = get_number e "timestamp";
        name = Option.value (get_string e "name") ~default:"";
        message = (if is_present message then text message else "");
        stack = get_string e "stack";
      })
    (list_of_array (Js.Unsafe.get t "exceptions"))

let truncated t =
  let v = Js.Unsafe.get t "truncated" in
  typeof v = "boolean" && Js.to_bool (Js.Unsafe.coerce v)

let wall_time t = get_number t "wallTime"
let cpu_time t = get_number t "cpuTime"
let of_js (v : js) : t = v
let to_js (t : t) : js = t

module Stream = struct
  type info =
    | Fetch of {
        method_ : string;
        url : string;
        headers : (string * string) list;
      }
    | Jsrpc
    | Scheduled of { cron : string; scheduled_time : float }
    | Alarm of { scheduled_time : float }
    | Queue of { queue : string; batch_size : int }
    | Email of { mail_from : string; rcpt_to : string; raw_size : int }
    | Trace of { traces : string option list }
    | Hibernatable_websocket of websocket_event
    | Custom
    | Other of js

  type onset = {
    info : info;
    span_id : string;
    script_name : string option;
    entrypoint : string option;
    execution_model : string;
    attributes : (string * Jsonkit.t) list;
  }

  type kind =
    | Onset of onset
    | Outcome of { outcome : outcome; cpu_time : float; wall_time : float }
    | Span_open of { name : string; span_id : string }
    | Span_close of { outcome : outcome }
    | Diagnostic_channel of { channel : string; message : Jsonkit.t }
    | Exception of { name : string; message : string; stack : string option }
    | Log of { level : level; message : Jsonkit.t }
    | Return of { status : int option }
    | Attributes of (string * Jsonkit.t) list
    | Other of js

  type t = js

  let string_field o name = Option.value (get_string o name) ~default:""

  let attributes v =
    List.map
      (fun a -> (string_field a "name", json_arg (Js.Unsafe.get a "value")))
      (list_of_array v)

  let info i =
    match get_string i "type" with
    | Some "fetch" ->
        Fetch
          {
            method_ = string_field i "method";
            url = string_field i "url";
            headers =
              List.map
                (fun h -> (string_field h "name", string_field h "value"))
                (list_of_array (Js.Unsafe.get i "headers"));
          }
    | Some "jsrpc" -> Jsrpc
    | Some "scheduled" ->
        Scheduled
          {
            cron = string_field i "cron";
            scheduled_time = time (Js.Unsafe.get i "scheduledTime");
          }
    | Some "alarm" ->
        Alarm { scheduled_time = time (Js.Unsafe.get i "scheduledTime") }
    | Some "queue" ->
        Queue
          {
            queue = string_field i "queueName";
            batch_size = Option.value (get_int i "batchSize") ~default:0;
          }
    | Some "email" ->
        Email
          {
            mail_from = string_field i "mailFrom";
            rcpt_to = string_field i "rcptTo";
            raw_size = Option.value (get_int i "rawSize") ~default:0;
          }
    | Some "trace" ->
        Trace
          {
            traces =
              List.map
                (fun s -> if is_present s then Some (text s) else None)
                (list_of_array (Js.Unsafe.get i "traces"));
          }
    | Some "hibernatableWebSocket" ->
        let ws = Js.Unsafe.get i "info" in
        Hibernatable_websocket
          (match get_string ws "type" with
          | Some "close" ->
              Ws_close
                {
                  code = Option.value (get_int ws "code") ~default:0;
                  was_clean =
                    (let v = Js.Unsafe.get ws "wasClean" in
                     typeof v = "boolean" && Js.to_bool (Js.Unsafe.coerce v));
                }
          | Some "error" -> Ws_error
          | _ -> Ws_message)
    | Some "custom" -> Custom
    | _ -> Other i

  let outcome_of o = outcome_of_string (get_string o "outcome")

  let kind t =
    let e = Js.Unsafe.get t "event" in
    match get_string e "type" with
    | Some "onset" ->
        Onset
          {
            info = info (Js.Unsafe.get e "info");
            span_id = string_field e "spanId";
            script_name = get_string e "scriptName";
            entrypoint = get_string e "entrypoint";
            execution_model = string_field e "executionModel";
            attributes = attributes (Js.Unsafe.get e "attributes");
          }
    | Some "outcome" ->
        Outcome
          {
            outcome = outcome_of e;
            cpu_time = get_number e "cpuTime";
            wall_time = get_number e "wallTime";
          }
    | Some "spanOpen" ->
        Span_open
          { name = string_field e "name"; span_id = string_field e "spanId" }
    | Some "spanClose" -> Span_close { outcome = outcome_of e }
    | Some "diagnosticChannel" ->
        Diagnostic_channel
          {
            channel = string_field e "channel";
            message = json_arg (Js.Unsafe.get e "message");
          }
    | Some "exception" ->
        Exception
          {
            name = string_field e "name";
            message = string_field e "message";
            stack = get_string e "stack";
          }
    | Some "log" ->
        Log
          {
            level = level_of_string (string_field e "level");
            message = json_arg (Js.Unsafe.get e "message");
          }
    | Some "return" ->
        let i = Js.Unsafe.get e "info" in
        Return
          { status = (if is_present i then get_int i "statusCode" else None) }
    | Some "attributes" -> Attributes (attributes (Js.Unsafe.get e "info"))
    | _ -> Other e

  let invocation_id t = string_field t "invocationId"
  let span_context t = Js.Unsafe.get t "spanContext"
  let trace_id t = string_field (span_context t) "traceId"
  let parent_span_id t = get_string (span_context t) "spanId"
  let timestamp t = time (Js.Unsafe.get t "timestamp")
  let sequence t = Option.value (get_int t "sequence") ~default:0
  let of_js (v : js) : t = v
  let to_js (t : t) : js = t
end
