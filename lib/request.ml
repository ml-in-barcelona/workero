module Js = Js_of_ocaml.Js
open Internal

type t = js

let method_ r = Method.of_string (Js.to_string (Js.Unsafe.get r "method"))

let url r =
  let s = Js.to_string (Js.Unsafe.get r "url") in
  match Url.of_string s with
  | Some u -> u
  | None -> invalid_arg ("Workero.Request.url: " ^ s)

let header = Wire.header
let headers = Wire.headers
let text = Wire.text
let bytes = Wire.bytes

let cf r =
  let v : js Js.opt = Js.Unsafe.get r "cf" in
  match Js.Opt.to_option v with
  | Some v -> Cf.of_js v
  | None -> Cf.of_js (Js.Unsafe.obj [||])

let of_js (v : js) : t = v
let to_js (t : t) : js = t
