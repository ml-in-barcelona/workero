module Js = Js_of_ocaml.Js
open Internal

let root () =
  let g = Js.Unsafe.global in
  if typeof (Js.Unsafe.get g "__workero") = "undefined" then
    Js.Unsafe.set g "__workero" (Js.Unsafe.obj [||]);
  Js.Unsafe.get g "__workero"

let set name (v : js) = Js.Unsafe.set (root ()) name v
