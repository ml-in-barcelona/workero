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

let header_all msg name =
  let name = String.lowercase_ascii name in
  List.filter_map
    (fun (k, v) -> if k = name then Some v else None)
    (headers msg)

let read ~decode msg name =
  Promise.await (Promise.of_js ~decode (meth msg name [||]))

let text msg = read ~decode:Decode.string msg "text"
let bytes msg = read ~decode:Decode.bytes msg "arrayBuffer"

let body_of_string s =
  Js.Unsafe.inject (Typed_array.Bytes.to_uint8Array (Bytes.unsafe_of_string s))

let fetch_init ~who ?signal ?(method_ = Method.GET) ?(headers = []) ?body () =
  (match (method_, body) with
  | (Method.GET | HEAD), Some _ ->
      invalid_arg (who ^ ": a GET or HEAD request has no body")
  | _ -> ());
  let fields =
    [
      ("method", str (Method.to_string method_));
      ("headers", headers_of_list headers);
    ]
    @ (match body with Some b -> [ ("body", body_of_string b) ] | None -> [])
    @
    match signal with
    | Some s -> [ ("signal", Abort_signal.to_js s) ]
    | None -> []
  in
  Js.Unsafe.obj (Array.of_list fields)
