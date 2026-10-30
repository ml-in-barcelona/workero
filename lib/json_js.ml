module Js = Js_of_ocaml.Js
open Internal

let k_length = str "length"
let t_string = str "string"
let t_boolean = str "boolean"
let t_number = str "number"
let is_array = Js.Unsafe.get (global "Array") "isArray"
let object_keys = Js.Unsafe.get (global "Object") "keys"

let rec read (v : js) : Jsonkit.t =
  let t = Js.Unsafe.coerce (Js.typeof (Js.Unsafe.coerce v)) in
  if js_equals t t_string then `String (Js.to_string (Js.Unsafe.coerce v))
  else if js_equals t t_number then
    let f = Js.float_of_number (Js.Unsafe.coerce v) in
    match int_of_number f with Some n -> `Int n | None -> `Float f
  else if js_equals t t_boolean then `Bool (Js.to_bool (Js.Unsafe.coerce v))
  else if is_nullish v then `Null
  else if Js.to_bool (call is_array [| v |]) then
    `List
      (List.init
         (int_of_js (Js.Unsafe.get v k_length))
         (fun i -> read (Js.Unsafe.get v i)))
  else
    let keys = call object_keys [| v |] in
    `Assoc
      (List.init
         (int_of_js (Js.Unsafe.get keys k_length))
         (fun i ->
           let key = Js.Unsafe.get keys i in
           (Js.to_string (Js.Unsafe.coerce key), read (Js.Unsafe.get v key))))

let of_js (v : js) : Jsonkit.t =
  let text =
    try meth (global "JSON") "stringify" [| v |]
    with Js.Js_error.Exn e ->
      invalid_arg ("Workero.JSON.of_js: " ^ Js.Js_error.message e)
  in
  if typeof text <> "string" then
    invalid_arg "Workero.JSON.of_js: the value has no JSON form";
  read (meth (global "JSON") "parse" [| text |])

let to_js (json : Jsonkit.t) : js =
  let text =
    try Jsonkit.to_string json
    with Yojson.Json_error message ->
      invalid_arg ("Workero.JSON.to_js: " ^ message)
  in
  meth (global "JSON") "parse" [| str text |]
