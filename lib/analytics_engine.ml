module Js = Js_of_ocaml.Js
open Internal

type t = js
type blob = Text of string | Bytes of string

let of_env env name =
  Binding.of_env ~who:"Workero.Analytics_engine.of_env"
    ~what:"an Analytics Engine dataset" ~methods:[ "writeDataPoint" ] env name

let js_array values = Js.Unsafe.inject (Js.array (Array.of_list values))

let js_blob = function
  | Text s -> str s
  | Bytes s -> Js.Unsafe.get (Wire.body_of_string s) "buffer"

let write ?index ?(doubles = []) ?(blobs = []) t =
  let fields =
    Option.fold index ~none:[] ~some:(fun i ->
        [ ("indexes", js_array [ str i ]) ])
    @ [
        ( "doubles",
          js_array
            (List.map
               (fun d -> Js.Unsafe.inject (Js.number_of_float d))
               doubles) );
        ("blobs", js_array (List.map js_blob blobs));
      ]
  in
  ignore (Binding.invoke t "writeDataPoint" [| Binding.options fields |])

let of_js (v : js) : t = v
let to_js (t : t) : js = t
