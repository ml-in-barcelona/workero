module Js = Js_of_ocaml.Js
open Internal

type t = js

let wait_until ctx f =
  let work =
    Async.run (fun () ->
        f ();
        Js.Unsafe.inject Js.undefined)
  in
  ignore
    (meth ctx "waitUntil" [| meth (global "Promise") "resolve" [| work |] |])

let pass_through_on_exception ctx =
  ignore (meth ctx "passThroughOnException" [||])

let of_js (v : js) : t = v
let to_js (t : t) : js = t
