module Js = Js_of_ocaml.Js
open Internal

type 'a t = js

let make (f : resolve:('a -> unit) -> reject:(string -> unit) -> unit) : 'a t =
  let executor =
    Js.wrap_callback (fun (res : js) (rej : js) ->
        let resolve (v : 'a) = ignore (call res [| Js.Unsafe.inject v |]) in
        let reject msg =
          let err = Js.Unsafe.new_obj (global "Error") [| str msg |] in
          ignore (call rej [| err |])
        in
        f ~resolve ~reject)
  in
  Js.Unsafe.new_obj (global "Promise") [| Js.Unsafe.inject executor |]

let resolve (v : 'a) : 'a t =
  meth (global "Promise") "resolve" [| Js.Unsafe.inject v |]

let reject msg : 'a t =
  let err = Js.Unsafe.new_obj (global "Error") [| str msg |] in
  meth (global "Promise") "reject" [| err |]

let await (p : 'a t) : 'a = Async.await p
let of_js (p : js) : 'a t = p
let to_js (p : 'a t) : js = p
