module Js = Js_of_ocaml.Js
open Internal

type t = js
type body = Json of Jsonkit.t | Text of string | Bytes of string
type message = js

let max_delay_seconds = 86400

let check_delay who = function
  | Some d when d < 0 || d > max_delay_seconds ->
      invalid_arg
        (Printf.sprintf "%s: delay_seconds %d is outside 0 to %d" who d
           max_delay_seconds)
  | _ -> ()

let of_env env name =
  Binding.of_env ~who:"Workero.Queue.of_env" ~what:"a queue producer"
    ~methods:[ "send"; "sendBatch" ] env name

let content_type_and_value = function
  | Json json -> ("json", Json_js.to_js json)
  | Text s -> ("text", str s)
  | Bytes s -> ("bytes", Wire.body_of_string s)

let delay_field = function
  | Some d -> [ ("delaySeconds", Js.Unsafe.inject (d : int)) ]
  | None -> []

let message ?delay_seconds body =
  check_delay "Workero.Queue.message" delay_seconds;
  let content_type, value = content_type_and_value body in
  Binding.options
    ([ ("body", value); ("contentType", str content_type) ]
    @ delay_field delay_seconds)

let send ?delay_seconds queue body =
  check_delay "Workero.Queue.send" delay_seconds;
  let content_type, value = content_type_and_value body in
  Binding.call ~decode:Decode.unit queue "send"
    [|
      value;
      Binding.options
        (("contentType", str content_type) :: delay_field delay_seconds);
    |]

let send_batch ?delay_seconds queue messages =
  check_delay "Workero.Queue.send_batch" delay_seconds;
  Binding.call ~decode:Decode.unit queue "sendBatch"
    [|
      Js.Unsafe.inject (Js.array (Array.of_list messages));
      Binding.options (delay_field delay_seconds);
    |]

module Message = struct
  type t = js

  let id m = Decode.field "id" Decode.string m
  let attempts m = Decode.field "attempts" Decode.int m

  let timestamp m =
    let v = Js.Unsafe.get m "timestamp" in
    if typeof v = "object" && instance_of v (global "Date") then
      Decode.float (meth v "getTime" [||])
    else Decode.float v

  let body m = Js.Unsafe.get m "body"
  let body_json m = Json_js.of_js (body m)
  let body_text m = Decode.string (body m)
  let body_bytes m = Decode.bytes (body m)
  let body_js = body
  let ack m = ignore (Binding.invoke m "ack" [||])

  let retry ?delay_seconds m =
    check_delay "Workero.Queue.Message.retry" delay_seconds;
    let args =
      match delay_seconds with
      | None -> [||]
      | Some _ -> [| Binding.options (delay_field delay_seconds) |]
    in
    ignore (Binding.invoke m "retry" args)

  let of_js (v : js) : t = v
  let to_js (t : t) : js = t
end

module Batch = struct
  type t = js

  let queue b = Decode.field "queue" Decode.string b
  let messages b = Decode.field "messages" (Decode.list Decode.js) b
  let ack_all b = ignore (Binding.invoke b "ackAll" [||])

  let retry_all ?delay_seconds b =
    check_delay "Workero.Queue.Batch.retry_all" delay_seconds;
    let args =
      match delay_seconds with
      | None -> [||]
      | Some _ -> [| Binding.options (delay_field delay_seconds) |]
    in
    ignore (Binding.invoke b "retryAll" args)

  let of_js (v : js) : t = v
  let to_js (t : t) : js = t
end

let of_js (v : js) : t = v
let to_js (t : t) : js = t
