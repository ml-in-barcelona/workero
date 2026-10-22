module Js = Js_of_ocaml.Js
open Internal

type t = js

module Reader = struct
  type t = js

  let chunk v =
    if Decode.(field "done" bool) v then None
    else Some (Decode.(field "value" bytes) v)

  let read r = Binding.call ~decode:chunk r "read" [||]

  let cancel ?reason r =
    let args = match reason with Some s -> [| str s |] | None -> [||] in
    Binding.call ~decode:Decode.unit r "cancel" args

  let release r = ignore (Binding.invoke r "releaseLock" [||])
end

module Writer = struct
  type t = js

  let write w s =
    Binding.call ~decode:Decode.unit w "write" [| Wire.body_of_string s |]

  let close w = Binding.call ~decode:Decode.unit w "close" [||]

  let abort ?reason w =
    let args = match reason with Some s -> [| str s |] | None -> [||] in
    Binding.call ~decode:Decode.unit w "abort" args

  let release w = ignore (Binding.invoke w "releaseLock" [||])
  let of_js (v : js) : t = v
end

let reader s : Reader.t = Binding.invoke s "getReader" [||]

let iter f s =
  let r = reader s in
  let rec loop () =
    match Reader.read r with
    | Some chunk -> (
        match f chunk with
        | () -> loop ()
        | exception e ->
            (try Reader.cancel r with Promise.Js_error _ -> ());
            raise e)
    | None -> ()
  in
  loop ()

let pipe () =
  let ts = Js.Unsafe.new_obj (global "TransformStream") [||] in
  let writer = meth (Js.Unsafe.get ts "writable") "getWriter" [||] in
  (writer, Js.Unsafe.get ts "readable")

let of_js (v : js) : t = v
let to_js (t : t) : js = t
