module Js = Js_of_ocaml.Js
open Internal

let default () = Js.Unsafe.get (global "caches") "default"

let match_ url =
  Option.map Response.of_js
    (Binding.call_opt ~decode:Decode.js (default ()) "match" [| str url |])

let put url response =
  Binding.call ~decode:Decode.unit (default ()) "put"
    [| str url; Response.to_js response |]

let delete url =
  Binding.call ~decode:Decode.bool (default ()) "delete" [| str url |]
