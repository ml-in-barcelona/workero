module Js = Js_of_ocaml.Js
open Internal

exception Non_retryable of string

let () =
  Printexc.register_printer (function
    | Non_retryable m -> Some (Printf.sprintf "Workflow.Non_retryable(%S)" m)
    | _ -> None)

let flushing f = Fun.protect ~finally:flush_all f
let number n = Js.Unsafe.inject (Js.number_of_float (float_of_int n))
let value_of_js v = Rpc.to_value (Rpc.of_js v)
let value_to_js (v : Rpc.value) = Rpc.to_js (v :> Rpc.t)

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

type schedule = { cron : string; scheduled_time : float }

type event = {
  payload : Rpc.value;
  timestamp : float;
  instance_id : string;
  workflow_name : string;
  schedule : schedule option;
}

let time_of_js v =
  if typeof v = "number" then Js.float_of_number (Js.Unsafe.coerce v)
  else Js.float_of_number (Js.Unsafe.coerce (meth v "getTime" [||]))

let schedule_of_js v =
  {
    cron = Decode.(field "cron" string) v;
    scheduled_time = Decode.(field "scheduledTime" float) v;
  }

let event_of_js v =
  {
    payload = value_of_js (Js.Unsafe.get v "payload");
    timestamp = time_of_js (Js.Unsafe.get v "timestamp");
    instance_id = Decode.(field "instanceId" string) v;
    workflow_name = Decode.(field "workflowName" string) v;
    schedule = Decode.(field "schedule" (option schedule_of_js)) v;
  }

let error_of_js e =
  (Decode.(field "name" string) e, Decode.(field "message" string) e)

let rpc_call ~decode stub name args =
  let args = Js.Unsafe.inject (Js.array (Array.of_list args)) in
  Promise.await
    (Promise.of_js ~decode
       (Binding.invoke (global "Reflect") "apply"
          [| Js.Unsafe.get stub name; stub; args |]))

module Step = struct
  type t = js
  type backoff = Constant | Linear | Exponential
  type config = { retries_limit : int option; backoff : backoff option }

  type context = {
    attempt : int;
    step_name : string;
    step_count : int;
    config : config;
  }

  type delay_context = { delay_ctx : context; delay_error : string * string }
  type delay = Fixed of Duration.t | Dynamic of (delay_context -> Duration.t)
  type retries = { limit : int; delay : delay; backoff : backoff option }

  let check_limit ~who limit =
    if limit < 0 || limit > 10_000 then
      invalid_arg (who ^ ": limit must be in 0..10000")

  let retries ?backoff ~limit ~delay () =
    check_limit ~who:"Workero.Workflow.Step.retries" limit;
    { limit; delay = Fixed delay; backoff }

  let retries_with ?backoff ~limit delay =
    check_limit ~who:"Workero.Workflow.Step.retries_with" limit;
    { limit; delay = Dynamic delay; backoff }

  let backoff_name = function
    | Constant -> "constant"
    | Linear -> "linear"
    | Exponential -> "exponential"

  let backoff_of_name = function
    | "constant" -> Some Constant
    | "linear" -> Some Linear
    | "exponential" -> Some Exponential
    | _ -> None

  let present v = not (is_nullish v || typeof v = "undefined")

  let config_of_js v =
    let retries = if present v then Js.Unsafe.get v "retries" else v in
    if present retries then
      {
        retries_limit = Decode.(field "limit" (option int)) retries;
        backoff =
          Option.bind
            Decode.(field "backoff" (option string) retries)
            backoff_of_name;
      }
    else { retries_limit = None; backoff = None }

  let context_of_js v =
    let step = Js.Unsafe.get v "step" in
    {
      attempt = Decode.(field "attempt" int) v;
      step_name = Decode.(field "name" string) step;
      step_count = Decode.(field "count" int) step;
      config = config_of_js (Js.Unsafe.get v "config");
    }

  let delay_to_js = function
    | Fixed d -> Duration.to_js d
    | Dynamic f ->
        Js.Unsafe.inject
          (Async.promising (fun (arg : js) : js ->
               Async.run (fun () ->
                   Duration.to_js
                     (f
                        {
                          delay_ctx = context_of_js (Js.Unsafe.get arg "ctx");
                          delay_error = error_of_js (Js.Unsafe.get arg "error");
                        }))))

  let check_name ~who name =
    check_length ~who ~what:"the step name" ~max:256 name

  let config ?retries ?timeout () =
    let field name f = Option.map (fun v -> (name, f v)) in
    let retries_js r =
      Binding.options
        (List.filter_map Fun.id
           [
             Some ("limit", number r.limit);
             Some ("delay", delay_to_js r.delay);
             field "backoff" (fun b -> str (backoff_name b)) r.backoff;
           ])
    in
    List.filter_map Fun.id
      [
        field "retries" retries_js retries;
        field "timeout" Duration.to_js timeout;
      ]

  type rollback_context = {
    rollback_ctx : context;
    rollback_error : string * string;
    rollback_output : Rpc.value;
  }

  type rollback = {
    handler : rollback_context -> unit;
    rollback_retries : retries option;
    rollback_timeout : Duration.t option;
  }

  let rollback ?retries ?timeout handler =
    { handler; rollback_retries = retries; rollback_timeout = timeout }

  let rollback_to_js r =
    let handler =
      Async.promising (fun (arg : js) : js ->
          Async.run (fun () ->
              mapping_non_retryable (fun () ->
                  r.handler
                    {
                      rollback_ctx = context_of_js (Js.Unsafe.get arg "ctx");
                      rollback_error = error_of_js (Js.Unsafe.get arg "error");
                      rollback_output = value_of_js (Js.Unsafe.get arg "output");
                    };
                  Js.Unsafe.inject Js.undefined)))
    in
    Binding.options
      (("rollback", Js.Unsafe.inject handler)
      ::
      (match
         config ?retries:r.rollback_retries ?timeout:r.rollback_timeout ()
       with
      | [] -> []
      | fields -> [ ("rollbackConfig", Binding.options fields) ]))

  let do_ ?retries ?timeout ?rollback t name f =
    check_name ~who:"Workero.Workflow.Step.do_" name;
    let callback =
      Async.promising (fun (ctx : js) : js ->
          Async.run (fun () ->
              mapping_non_retryable (fun () ->
                  value_to_js (f (context_of_js ctx)))))
    in
    let config = config ?retries ?timeout () in
    let args =
      match (rollback, config) with
      | None, [] -> [ str name; callback ]
      | None, fields -> [ str name; Binding.options fields; callback ]
      | Some r, fields ->
          [ str name; Binding.options fields; callback; rollback_to_js r ]
    in
    rpc_call ~decode:value_of_js t "do" args

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

  type step_event = {
    event_type : string;
    event_payload : Rpc.value;
    event_timestamp : float;
  }

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
        {
          event_type = Decode.(field "type" string) v;
          event_payload = value_of_js (Js.Unsafe.get v "payload");
          event_timestamp = time_of_js (Js.Unsafe.get v "timestamp");
        })
      t "waitForEvent"
      [ str name; options ]

  let of_js (v : js) : t = v
end

let classes () =
  let root = Registry.root () in
  if typeof (Js.Unsafe.get root "workflows") = "undefined" then
    Js.Unsafe.set root "workflows" (Js.Unsafe.obj [||]);
  Js.Unsafe.get root "workflows"

let register_with ~who ~event_of_js name run =
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
                value_to_js
                  (run (Env.of_js env) (event_of_js event) (Step.of_js step)))))
  in
  let run_fiber env event step : js =
    call (Async.promising run_js) [| env; event; step |]
  in
  Js.Unsafe.set (classes ()) name
    (Js.Unsafe.inject (Js.wrap_callback run_fiber))

let register name run =
  register_with ~who:"Workero.Workflow.register" ~event_of_js name run

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
    output : Rpc.value option;
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
        (if typeof output = "undefined" then None else Some (value_of_js output));
    }

  let status t = Binding.call ~decode:state_of_js t "status" [||]
  let pause t = Binding.call ~decode:Decode.unit t "pause" [||]
  let resume t = Binding.call ~decode:Decode.unit t "resume" [||]

  type step_kind = Do | Sleep | Wait_for_event

  type restart_from = {
    name : string;
    count : int option;
    kind : step_kind option;
  }

  let restart_from ?count ?kind name =
    Option.iter
      (fun n ->
        if n < 1 then
          invalid_arg "Workero.Workflow.Instance.restart_from: count is below 1")
      count;
    { name; count; kind }

  let kind_name = function
    | Do -> "do"
    | Sleep -> "sleep"
    | Wait_for_event -> "waitForEvent"

  let optional_args fields =
    match List.filter_map Fun.id fields with
    | [] -> [||]
    | fields -> [| Binding.options fields |]

  let terminate ?rollback t =
    Binding.call ~decode:Decode.unit t "terminate"
      (optional_args
         [
           Option.map
             (fun b -> ("rollback", Js.Unsafe.inject (Js.bool b)))
             rollback;
         ])

  let restart ?from t =
    let from_js (f : restart_from) =
      Binding.options
        (List.filter_map Fun.id
           [
             Some ("name", str f.name);
             Option.map (fun n -> ("count", number n)) f.count;
             Option.map (fun k -> ("type", str (kind_name k))) f.kind;
           ])
    in
    Binding.call ~decode:Decode.unit t "restart"
      (optional_args [ Option.map (fun f -> ("from", from_js f)) from ])

  let delete t = Binding.call ~decode:Decode.unit t "delete" [||]

  let send_event t ~type_ payload =
    Step.check_event_type ~who:"Workero.Workflow.Instance.send_event" type_;
    Binding.call ~decode:Decode.unit t "sendEvent"
      [|
        Binding.options
          [ ("type", str type_); ("payload", value_to_js payload) ];
      |]
end

type retention = js

let retention ?success ?error () =
  let field name = Option.map (fun d -> (name, Duration.to_js d)) in
  Binding.options
    (List.filter_map Fun.id
       [ field "successRetention" success; field "errorRetention" error ])

type options = js

let check_id id =
  Option.iter
    (check_length ~who:"Workero.Workflow.options" ~what:"the instance id"
       ~max:100)
    id

let options ?id ?params ?retention () =
  check_id id;
  let field name f = Option.map (fun v -> (name, f v)) in
  Binding.options
    (List.filter_map Fun.id
       [
         field "id" str id;
         field "params" value_to_js params;
         field "retention" Fun.id retention;
       ])

let create ?id ?params ?retention t =
  Binding.call ~decode:Decode.js t "create"
    [| options ?id ?params ?retention () |]

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

let check_count ~who ~what n =
  if n < 1 || n > 100 then
    invalid_arg (Printf.sprintf "%s: %s must be in 1..100" who what)

let create_batch_count ?params ?retention t ~count =
  check_count ~who:"Workero.Workflow.create_batch_count" ~what:"count" count;
  let field name f = Option.map (fun v -> (name, f v)) in
  Binding.call
    ~decode:(fun v ->
      ( Decode.(field "created" (list js)) v,
        Decode.(field "errors" (list batch_error_of_js)) v ))
    t "createBatch"
    [|
      Binding.options
        (List.filter_map Fun.id
           [
             Some ("count", number count);
             field "params" value_to_js params;
             field "retention" Fun.id retention;
           ]);
    |]

type delete_error = {
  failed_id : string;
  failed_code : int;
  failed_message : string;
}

let delete_batch t ids =
  check_count ~who:"Workero.Workflow.delete_batch" ~what:"the number of ids"
    (List.length ids);
  let ids = Js.Unsafe.inject (Js.array (Array.of_list (List.map str ids))) in
  Binding.call
    ~decode:(fun v ->
      ( Decode.(field "deleted" (list (field "id" string))) v,
        Decode.(
          field "errors"
            (list (fun e ->
                 {
                   failed_id = field "id" string e;
                   failed_code = field "code" int e;
                   failed_message = field "message" string e;
                 })))
          v ))
    t "deleteBatch" [| ids |]
