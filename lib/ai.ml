module Js = Js_of_ocaml.Js
open Internal

type t = js

let of_env env name =
  Binding.of_env ~who:"Workero.Ai.of_env" ~what:"a Workers AI binding"
    ~methods:[ "run" ] env name

type retries = js
type gateway = js

let opt name inject = function
  | Some v -> [ (name, Js.Unsafe.inject (inject v)) ]
  | None -> []

let retries ?max_attempts ?retry_delay_ms ?backoff () =
  (match max_attempts with
  | Some n when n < 1 || n > 5 ->
      invalid_arg
        (Printf.sprintf "Workero.Ai.retries: max_attempts %d is outside 1 to 5"
           n)
  | _ -> ());
  let backoff_name = function
    | `Constant -> "constant"
    | `Linear -> "linear"
    | `Exponential -> "exponential"
  in
  Binding.options
    (opt "maxAttempts" Fun.id max_attempts
    @ opt "retryDelayMs" Fun.id retry_delay_ms
    @ opt "backoff" (fun b -> str (backoff_name b)) backoff)

let metadata_value = function
  | (`Null | `Bool _ | `Int _ | `Float _ | `String _) as v -> Json_js.to_js v
  | _ ->
      invalid_arg
        "Workero.Ai.gateway: a metadata value must be null, a boolean, a \
         number or a string"

let gateway ?cache_key ?cache_ttl ?skip_cache ?collect_log ?event_id
    ?request_timeout_ms ?retries ?metadata id =
  Binding.options
    ([ ("id", str id) ]
    @ opt "cacheKey" str cache_key
    @ opt "cacheTtl" Fun.id cache_ttl
    @ opt "skipCache" Js.bool skip_cache
    @ opt "collectLog" Js.bool collect_log
    @ opt "eventId" str event_id
    @ opt "requestTimeoutMs" Fun.id request_timeout_ms
    @ opt "retries" Fun.id retries
    @ opt "metadata"
        (fun fields ->
          Binding.options
            (List.map (fun (k, v) -> (k, metadata_value v)) fields))
        metadata)

let decode_json v =
  if instance_of v (global "ReadableStream") then
    invalid_arg "Workero.Ai.run: the model answered with a stream";
  Json_js.of_js v

let run_with ~decode ?gateway ai model input =
  let args = [| str model; Json_js.to_js input |] in
  let args =
    match gateway with
    | None -> args
    | Some g -> Array.append args [| Binding.options [ ("gateway", g) ] |]
  in
  Binding.call ~decode ai "run" args

let decode_stream v =
  if instance_of v (global "ReadableStream") then Stream.of_js v
  else
    invalid_arg "Workero.Ai.run_stream: the model did not answer with a stream"

let with_stream = function
  | `Assoc fields ->
      `Assoc (("stream", `Bool true) :: List.remove_assoc "stream" fields)
  | _ -> invalid_arg "Workero.Ai.run_stream: the input must be a JSON object"

let run ?gateway ai model input =
  run_with ~decode:decode_json ?gateway ai model input

let run_bytes ?gateway ai model input =
  run_with ~decode:Decode.bytes ?gateway ai model input

let run_stream ?gateway ai model input =
  run_with ~decode:decode_stream ?gateway ai model (with_stream input)

let of_js (v : js) : t = v
let to_js (t : t) : js = t
