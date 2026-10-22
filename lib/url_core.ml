module Js = Js_of_ocaml.Js
open Internal

type t = js

let of_js v =
  match Js.Unsafe.new_obj (global "URL") [| v |] with
  | u -> (
      match get_string u "protocol" with
      | Some ("http:" | "https:") -> Some u
      | _ -> None)
  | exception Js.Js_error.Exn _ -> None
