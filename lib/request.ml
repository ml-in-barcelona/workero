module Js = Js_of_ocaml.Js
open Internal

type t = js

let method_ r = Method.of_string (Js.to_string (Js.Unsafe.get r "method"))

let url r =
  let v = Js.Unsafe.get r "url" in
  match Url.make v with
  | Some u -> u
  | None ->
      invalid_arg ("Workero.Request.url: " ^ Js.to_string (Js.Unsafe.coerce v))

let js_url r = Js.Unsafe.new_obj (global "URL") [| Js.Unsafe.get r "url" |]
let path r = Js.to_string (Js.Unsafe.get (js_url r) "pathname")

let query_string r =
  let search = Js.to_string (Js.Unsafe.get (js_url r) "search") in
  if search = "" then "" else String.sub search 1 (String.length search - 1)

let header = Wire.header
let header_all = Wire.header_all
let headers = Wire.headers
let text = Wire.text
let bytes = Wire.bytes

let cf r =
  let v : js Js.opt = Js.Unsafe.get r "cf" in
  match Js.Opt.to_option v with
  | Some v -> Cf.of_js v
  | None -> Cf.of_js (Js.Unsafe.obj [||])

let body r : Stream.t option =
  let v = Js.Unsafe.get r "body" in
  if is_nullish v then None else Some (Stream.of_js v)

let form_data r = Binding.call ~decode:Form_data.of_js r "formData" [||]
let signal r = Abort_signal.of_js (Js.Unsafe.get r "signal")
let clone r : t = Binding.invoke r "clone" [||]
let of_js (v : js) : t = v
let to_js (t : t) : js = t
