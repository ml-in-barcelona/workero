open Internal

type t = js

let of_env env name =
  Binding.of_env ~who:"Workero.Ai.of_env" ~what:"a Workers AI binding"
    ~methods:[ "run" ] env name

let decode_json v =
  if instance_of v (global "ReadableStream") then
    invalid_arg "Workero.Ai.run: the model answered with a stream";
  Json_js.of_js v

let run_with ~decode ai model input =
  Binding.call ~decode ai "run" [| str model; Json_js.to_js input |]

let run ai model input = run_with ~decode:decode_json ai model input
let run_bytes ai model input = run_with ~decode:Decode.bytes ai model input
let of_js (v : js) : t = v
let to_js (t : t) : js = t
