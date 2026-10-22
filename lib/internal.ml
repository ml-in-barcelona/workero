module Js = Js_of_ocaml.Js

type js = Js.Unsafe.any

let global name = Js.Unsafe.get Js.Unsafe.global name
let call f args = Js.Unsafe.fun_call f args
let meth o name args = Js.Unsafe.meth_call o name args
let str s = Js.Unsafe.inject (Js.string s)
let typeof v = Js.to_string (Js.typeof (Js.Unsafe.coerce v))

let get_string o name =
  let v = Js.Unsafe.get o name in
  if typeof v = "string" then Some (Js.to_string (Js.Unsafe.coerce v)) else None

let int_of_js v = int_of_float (Js.float_of_number (Js.Unsafe.coerce v))

let get_int o name =
  let v = Js.Unsafe.get o name in
  if typeof v = "number" then Some (int_of_js v) else None

external instance_of : js -> js -> bool = "caml_js_instanceof"
external js_equals : js -> js -> bool = "caml_js_equals"

let null : js = Js.Unsafe.inject Js.null
let is_nullish (v : js) = js_equals v null

let describe v =
  match typeof v with
  | "object" -> if is_nullish v then "null" else "an object"
  | "undefined" -> "undefined"
  | t -> "a " ^ t

let has_own o name =
  Js.to_bool (meth (global "Object") "hasOwn" [| o; str name |])

let is_identifier name =
  name <> ""
  && (match name.[0] with '0' .. '9' -> false | _ -> true)
  && String.for_all
       (function
         | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '$' -> true | _ -> false)
       name

let is_class_name name =
  is_identifier name && not (List.mem name [ "default"; "then"; "__proto__" ])
