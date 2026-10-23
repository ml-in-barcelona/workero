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

type event =
  | Fetch of { request : Request.t; status : int option }
  | Scheduled of { cron : string; scheduled_time : float }
  | Queue of { queue : string; batch_size : int }
  | Other of js

type t = js

let outcome t =
  match get_string t "outcome" with
  | Some "ok" -> Ok
  | Some "exception" -> Exception
  | Some "exceededCpu" -> Exceeded_cpu
  | Some "exceededMemory" -> Exceeded_memory
  | Some "scriptNotFound" -> Script_not_found
  | Some "canceled" -> Canceled
  | Some "responseStreamDisconnected" -> Response_stream_disconnected
  | Some other -> Unknown other
  | None -> Unknown "unknown"

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
    else Other e

let event_timestamp t = get_number t "eventTimestamp"
let script_name t = get_string t "scriptName"

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
