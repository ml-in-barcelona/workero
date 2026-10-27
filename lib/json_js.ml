module Js = Js_of_ocaml.Js
open Internal

let rec read (v : js) : Jsonkit.t =
  match typeof v with
  | "string" -> `String (Js.to_string (Js.Unsafe.coerce v))
  | "boolean" -> `Bool (Js.to_bool (Js.Unsafe.coerce v))
  | "number" -> (
      let f = Js.float_of_number (Js.Unsafe.coerce v) in
      match int_of_number f with Some n -> `Int n | None -> `Float f)
  | _ when is_nullish v -> `Null
  | _ when Js.to_bool (meth (global "Array") "isArray" [| v |]) ->
      `List
        (List.init
           (int_of_js (Js.Unsafe.get v "length"))
           (fun i -> read (Js.Unsafe.get v i)))
  | _ ->
      let keys = meth (global "Object") "keys" [| v |] in
      `Assoc
        (List.init
           (int_of_js (Js.Unsafe.get keys "length"))
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
