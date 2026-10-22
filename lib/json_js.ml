module Js = Js_of_ocaml.Js
open Internal

let of_js (v : js) : Jsonkit.t =
  let text =
    try meth (global "JSON") "stringify" [| v |]
    with Js.Js_error.Exn e ->
      invalid_arg ("Workero.JSON.of_js: " ^ Js.Js_error.message e)
  in
  if typeof text <> "string" then
    invalid_arg "Workero.JSON.of_js: the value has no JSON form";
  Jsonkit.of_string (Js.to_string (Js.Unsafe.coerce text))

let to_js (json : Jsonkit.t) : js =
  let text =
    try Jsonkit.to_string json
    with Yojson.Json_error message ->
      invalid_arg ("Workero.JSON.to_js: " ^ message)
  in
  meth (global "JSON") "parse" [| str text |]
