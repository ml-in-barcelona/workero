module Js = Js_of_ocaml.Js
module Typed_array = Js_of_ocaml.Typed_array
open Internal

type t =
  | Null
  | Int of int64
  | Float of float
  | Text of string
  | Blob of string

type row = (string * t) list

let max_safe = 9007199254740992L
let number f = Js.Unsafe.inject (Js.number_of_float f)

let to_js = function
  | Null -> Js.Unsafe.inject Js.null
  | Int n ->
      if
        Int64.compare n max_safe > 0 || Int64.compare n (Int64.neg max_safe) < 0
      then
        invalid_arg
          (Printf.sprintf "Workero.Sql_value.to_js: %Ld is beyond 2^53" n)
      else number (Int64.to_float n)
  | Float f -> number f
  | Text s -> str s
  | Blob s -> Wire.body_of_string s

let bytes_of_array_buffer v =
  Typed_array.String.of_uint8Array
    (Js.Unsafe.new_obj (global "Uint8Array") [| v |])

let bytes_of_view v =
  Typed_array.String.of_uint8Array
    (Js.Unsafe.new_obj (global "Uint8Array")
       [|
         Js.Unsafe.get v "buffer";
         Js.Unsafe.get v "byteOffset";
         Js.Unsafe.get v "byteLength";
       |])

let is_instance v name = instance_of v (global name)

let unsupported what =
  invalid_arg ("Workero.Sql_value.of_js: unsupported JS value of type " ^ what)

let int_of_bigint v =
  let s = Js.to_string (call (global "String") [| v |]) in
  match Int64.of_string_opt s with
  | Some n -> Int n
  | None ->
      invalid_arg
        (Printf.sprintf "Workero.Sql_value.of_js: %s is outside the int64 range"
           s)

let blob_of_object v =
  if Js.to_bool (meth (global "ArrayBuffer") "isView" [| v |]) then
    Blob (bytes_of_view v)
  else if is_instance v "ArrayBuffer" || is_instance v "Array" then
    Blob (bytes_of_array_buffer v)
  else unsupported "object"

let of_js (v : js) =
  if is_nullish v then Null
  else
    match typeof v with
    | "string" -> Text (Js.to_string (Js.Unsafe.coerce v))
    | "number" ->
        let f = Js.float_of_number (Js.Unsafe.coerce v) in
        if Float.is_integer f && Float.abs f <= Int64.to_float max_safe then
          Int (Int64.of_float f)
        else Float f
    | "bigint" -> int_of_bigint v
    | "object" -> blob_of_object v
    | other -> unsupported other
