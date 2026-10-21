module Js = Js_of_ocaml.Js
open Internal

type t = js

let null_body_statuses = [ 101; 204; 205; 304 ]

let build ?content_type ~status ~headers ~empty_body body =
  let h = Wire.headers_of_list headers in
  Option.iter
    (fun ct ->
      if not (Js.to_bool (meth h "has" [| str "content-type" |])) then
        ignore (meth h "set" [| str "content-type"; str ct |]))
    content_type;
  let init =
    Js.Unsafe.obj [| ("status", Js.Unsafe.inject status); ("headers", h) |]
  in
  let body =
    if List.mem status null_body_statuses && empty_body then
      Js.Unsafe.inject Js.null
    else body
  in
  Js.Unsafe.new_obj (global "Response") [| body; init |]

let text ?(status = 200) ?(headers = []) body =
  build ~status ~headers ~empty_body:(body = "") (str body)

let html ?(status = 200) ?(headers = []) body =
  build ~content_type:"text/html; charset=utf-8" ~status ~headers
    ~empty_body:(body = "") (str body)

let make ?(status = 200) ?(headers = []) body =
  build ~status ~headers ~empty_body:(body = "") (Wire.body_of_string body)

let redirect ?(status = 302) url =
  if not (List.mem status [ 301; 302; 303; 307; 308 ]) then
    invalid_arg (Printf.sprintf "Workero.Response.redirect: status %d" status);
  meth (global "Response") "redirect" [| str url; Js.Unsafe.inject status |]

let status r = int_of_js (Js.Unsafe.get r "status")
let header = Wire.header
let headers = Wire.headers
let body_text = Wire.text
let body_bytes = Wire.bytes
let of_js (v : js) : t = v
let to_js (t : t) : js = t
