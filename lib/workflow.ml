module Js = Js_of_ocaml.Js
open Internal

exception Non_retryable of string

let () =
  Printexc.register_printer (function
    | Non_retryable m -> Some (Printf.sprintf "Workflow.Non_retryable(%S)" m)
    | _ -> None)

let flushing f = Fun.protect ~finally:flush_all f
let number n = Js.Unsafe.inject (Js.number_of_float (float_of_int n))
let json_of_js v = if typeof v = "undefined" then `Null else Json_js.of_js v

let non_retryable message =
  let ctor = Js.Unsafe.get (Registry.root ()) "NonRetryableError" in
  let error =
    if typeof ctor = "function" then Js.Unsafe.new_obj ctor [| str message |]
    else
      let e = Js.Unsafe.new_obj (global "Error") [| str message |] in
      Js.Unsafe.set e "name" (str "NonRetryableError");
      e
  in
  Promise.Js_error (Promise.error_of_js error)

let mapping_non_retryable f =
  try f () with Non_retryable message -> raise (non_retryable message)

let check_length ~who ~what ~max s =
  if String.length s > max then
    invalid_arg
      (Printf.sprintf "%s: %s is longer than %d characters" who what max)

module Duration = struct
  type t = int

  let make ~who unit_ms n =
    if n < 0 then invalid_arg (who ^ ": negative duration");
    n * unit_ms

  let ms = make ~who:"Workero.Workflow.Duration.ms" 1
  let seconds = make ~who:"Workero.Workflow.Duration.seconds" 1_000
  let minutes = make ~who:"Workero.Workflow.Duration.minutes" 60_000
  let hours = make ~who:"Workero.Workflow.Duration.hours" 3_600_000
  let days = make ~who:"Workero.Workflow.Duration.days" 86_400_000
  let to_js (t : t) = number t
end

type event = { payload : Jsonkit.t; timestamp : float; instance_id : string }

let time_of_js v =
  if typeof v = "number" then Js.float_of_number (Js.Unsafe.coerce v)
  else Js.float_of_number (Js.Unsafe.coerce (meth v "getTime" [||]))

let event_of_js v =
  {
    payload = json_of_js (Js.Unsafe.get v "payload");
    timestamp = time_of_js (Js.Unsafe.get v "timestamp");
    instance_id = Decode.(field "instanceId" string) v;
  }

let rpc_call ~decode stub name args =
  let args = Js.Unsafe.inject (Js.array (Array.of_list args)) in
  Promise.await
    (Promise.of_js ~decode
       (Binding.invoke (global "Reflect") "apply"
          [| Js.Unsafe.get stub name; stub; args |]))

module Step = struct
  type t = js
  type backoff = Constant | Linear | Exponential
  type retries = { limit : int; delay : Duration.t; backoff : backoff option }

  let retries ?backoff ~limit ~delay () =
    if limit < 0 || limit > 10_000 then
      invalid_arg "Workero.Workflow.Step.retries: limit must be in 0..10000";
    { limit; delay; backoff }

  let backoff_name = function
    | Constant -> "constant"
    | Linear -> "linear"
    | Exponential -> "exponential"

  let check_name ~who name =
    check_length ~who ~what:"the step name" ~max:256 name

  let config ?retries ?timeout () =
    let field name f = Option.map (fun v -> (name, f v)) in
    let retries_js r =
      Binding.options
        (List.filter_map Fun.id
           [
             Some ("limit", number r.limit);
             Some ("delay", Duration.to_js r.delay);
             field "backoff" (fun b -> str (backoff_name b)) r.backoff;
           ])
    in
    List.filter_map Fun.id
      [
        field "retries" retries_js retries;
        field "timeout" Duration.to_js timeout;
      ]

  let do_ ?retries ?timeout t name f =
    check_name ~who:"Workero.Workflow.Step.do_" name;
    let callback =
      Async.promising (fun (_ctx : js) : js ->
          Async.run (fun () ->
              mapping_non_retryable (fun () -> Json_js.to_js (f ()))))
    in
    let args =
      match config ?retries ?timeout () with
      | [] -> [| str name; callback |]
      | fields -> [| str name; Binding.options fields; callback |]
    in
    rpc_call ~decode:json_of_js t "do" (Array.to_list args)

  let sleep t name duration =
    check_name ~who:"Workero.Workflow.Step.sleep" name;
    rpc_call ~decode:Decode.unit t "sleep" [ str name; Duration.to_js duration ]

  let sleep_until t name at =
    check_name ~who:"Workero.Workflow.Step.sleep_until" name;
    rpc_call ~decode:Decode.unit t "sleepUntil"
      [ str name; Js.Unsafe.inject (Js.number_of_float at) ]

  let valid_event_type_char = function
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '_' -> true
    | _ -> false

  let check_event_type ~who type_ =
    check_length ~who ~what:"the event type" ~max:100 type_;
    if type_ = "" || not (String.for_all valid_event_type_char type_) then
      invalid_arg
        (Printf.sprintf
           "%s: the event type %S must have only letters, digits, - and _" who
           type_)

  let wait_for_event ?timeout t name ~type_ =
    let who = "Workero.Workflow.Step.wait_for_event" in
    check_name ~who name;
    check_event_type ~who type_;
    let options =
      Binding.options
        (("type", str type_)
        ::
        (match timeout with
        | None -> []
        | Some d -> [ ("timeout", Duration.to_js d) ]))
    in
    rpc_call
      ~decode:(fun v ->
        if is_nullish v then `Null else json_of_js (Js.Unsafe.get v "payload"))
      t "waitForEvent"
      [ str name; options ]

  let of_js (v : js) : t = v
end

let classes () =
  let root = Registry.root () in
  if typeof (Js.Unsafe.get root "workflows") = "undefined" then
    Js.Unsafe.set root "workflows" (Js.Unsafe.obj [||]);
  Js.Unsafe.get root "workflows"

let register name run =
  let who = "Workero.Workflow.register" in
  if not (is_class_name name) then
    invalid_arg (Printf.sprintf "%s: %S is not a valid class name" who name);
  let root = Registry.root () in
  let taken table =
    let t = Js.Unsafe.get root table in
    typeof t <> "undefined" && has_own t name
  in
  if taken "durable_objects" || taken "entrypoints" || has_own (classes ()) name
  then
    invalid_arg (Printf.sprintf "%s: class %S is already registered" who name);
  let run_js env event step : js =
    Async.run (fun () ->
        flushing (fun () ->
            mapping_non_retryable (fun () ->
                Json_js.to_js
                  (run (Env.of_js env) (event_of_js event) (Step.of_js step)))))
  in
  let run_fiber env event step : js =
    call (Async.promising run_js) [| env; event; step |]
  in
  Js.Unsafe.set (classes ()) name
    (Js.Unsafe.inject (Js.wrap_callback run_fiber))

type t = js

let of_env env name =
  Binding.of_env ~who:"Workero.Workflow.of_env" ~what:"a Workflow binding"
    ~methods:[ "create"; "createBatch"; "get" ]
    env name

module Instance = struct
  type t = js

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
    error : (string * string) option;
    output : Jsonkit.t option;
  }

  let id t = Decode.(field "id" string) t

  let status_of_string = function
    | "queued" -> Queued
    | "running" -> Running
    | "paused" -> Paused
    | "errored" -> Errored
    | "terminated" -> Terminated
    | "complete" -> Complete
    | "waiting" -> Waiting
    | "waitingForPause" -> Waiting_for_pause
    | _ -> Unknown

  let state_of_js v =
    let error = Js.Unsafe.get v "error" in
    let output = Js.Unsafe.get v "output" in
    {
      status = status_of_string (Decode.(field "status" string) v);
      error =
        (if is_nullish error || typeof error = "undefined" then None
         else
           Some
             ( Decode.(field "name" string) error,
               Decode.(field "message" string) error ));
      output =
        (if typeof output = "undefined" then None else Some (json_of_js output));
    }

  let status t = Binding.call ~decode:state_of_js t "status" [||]
  let pause t = Binding.call ~decode:Decode.unit t "pause" [||]
  let resume t = Binding.call ~decode:Decode.unit t "resume" [||]
  let terminate t = Binding.call ~decode:Decode.unit t "terminate" [||]
  let restart t = Binding.call ~decode:Decode.unit t "restart" [||]

  let send_event t ~type_ payload =
    Step.check_event_type ~who:"Workero.Workflow.Instance.send_event" type_;
    Binding.call ~decode:Decode.unit t "sendEvent"
      [|
        Binding.options
          [ ("type", str type_); ("payload", Json_js.to_js payload) ];
      |]
end

type options = js

let options ?id ?params () =
  Option.iter
    (check_length ~who:"Workero.Workflow.options" ~what:"the instance id"
       ~max:100)
    id;
  let field name f = Option.map (fun v -> (name, f v)) in
  Binding.options
    (List.filter_map Fun.id
       [ field "id" str id; field "params" Json_js.to_js params ])

let create ?id ?params t =
  Binding.call ~decode:Decode.js t "create" [| options ?id ?params () |]

type batch_error = {
  index : int;
  id : string option;
  code : int;
  message : string;
}

let batch_error_of_js v =
  {
    index = Decode.(field "index" int) v;
    id = Decode.(field "id" (option string)) v;
    code = Decode.(field "code" int) v;
    message = Decode.(field "message" string) v;
  }

let create_batch t items =
  let instances = Js.Unsafe.inject (Js.array (Array.of_list items)) in
  Binding.call
    ~decode:(fun v ->
      ( Decode.(field "created" (list js)) v,
        Decode.(field "errors" (list batch_error_of_js)) v ))
    t "createBatch"
    [| Binding.options [ ("instances", instances) ] |]

let get t id = Binding.call ~decode:Decode.js t "get" [| str id |]
