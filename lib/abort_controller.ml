module Js = Js_of_ocaml.Js
open Internal

type t = js

let create () : t = Js.Unsafe.new_obj (global "AbortController") [||]
let signal c = Abort_signal.of_js (Js.Unsafe.get c "signal")

let abort ?reason c =
  match reason with
  | None -> ignore (meth c "abort" [||])
  | Some r -> ignore (meth c "abort" [| abort_reason r |])
