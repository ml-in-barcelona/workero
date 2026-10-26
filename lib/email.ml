module Js = Js_of_ocaml.Js
open Internal

type t = js

let from m = Decode.field "from" Decode.string m
let to_ m = Decode.field "to" Decode.string m
let header = Wire.header
let header_all = Wire.header_all
let headers = Wire.headers
let raw_size m = Decode.field "rawSize" Decode.int m
let raw m = Stream.of_js (Js.Unsafe.get m "raw")

let raw_response m =
  Binding.guard (fun () ->
      Js.Unsafe.new_obj (global "Response") [| Js.Unsafe.get m "raw" |])

let raw_text m = Wire.text (raw_response m)
let raw_bytes m = Wire.bytes (raw_response m)
let set_reject m reason = ignore (Binding.invoke m "setReject" [| str reason |])

let forward ?headers m to_ =
  let args =
    match headers with
    | None -> [| str to_ |]
    | Some h -> [| str to_; Wire.headers_of_list h |]
  in
  Binding.call ~decode:Decode.unit m "forward" args

let reply m ~from ~to_ raw =
  let raw = match raw with `Text s -> str s | `Stream s -> Stream.to_js s in
  let message =
    Binding.call ~decode:Decode.js (Registry.root ()) "emailMessage"
      [| str from; str to_; raw |]
  in
  Binding.call ~decode:Decode.unit m "reply" [| message |]

let of_js (v : js) : t = v
let to_js (t : t) : js = t
