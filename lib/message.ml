module Js = Js_of_ocaml.Js
module Typed_array = Js_of_ocaml.Typed_array
open Internal

let headers_of_list pairs =
  let h = Js.Unsafe.new_obj (global "Headers") [||] in
  List.iter (fun (k, v) -> ignore (meth h "append" [| str k; str v |])) pairs;
  h

let header msg name =
  let v : Js.js_string Js.t Js.opt =
    meth (Js.Unsafe.get msg "headers") "get" [| str name |]
  in
  Option.map Js.to_string (Js.Opt.to_option v)

let headers msg =
  let entries = meth (Js.Unsafe.get msg "headers") "entries" [||] in
  let all : js = meth (global "Array") "from" [| entries |] in
  let n = int_of_js (Js.Unsafe.get all "length") in
  List.init n (fun i ->
      let pair : js = Js.Unsafe.get all i in
      (Js.to_string (Js.Unsafe.get pair 0), Js.to_string (Js.Unsafe.get pair 1)))

let text msg =
  let p : Js.js_string Js.t Promise.t = Promise.of_js (meth msg "text" [||]) in
  Js.to_string (Promise.await p)

let bytes msg =
  let p : Typed_array.arrayBuffer Js.t Promise.t =
    Promise.of_js (meth msg "arrayBuffer" [||])
  in
  Typed_array.String.of_arrayBuffer (Promise.await p)

let body_of_string s =
  Js.Unsafe.inject (Typed_array.Bytes.to_uint8Array (Bytes.of_string s))
