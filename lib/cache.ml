module Js = Js_of_ocaml.Js
open Internal

let default () = Js.Unsafe.get (global "caches") "default"

let match_ url =
  Option.map Response.of_js
    (Binding.call_opt (default ()) "match" [| str url |])

let put url response =
  let _ : js =
    Binding.call (default ()) "put" [| str url; Response.to_js response |]
  in
  ()

let delete url =
  let deleted : bool Js.t = Binding.call (default ()) "delete" [| str url |] in
  Js.to_bool deleted
