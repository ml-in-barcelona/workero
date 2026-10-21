module Js = Js_of_ocaml.Js
module Typed_array = Js_of_ocaml.Typed_array
open Internal

type 'a t = js -> 'a

let fail expected v =
  invalid_arg
    (Printf.sprintf "Workero.Decode: expected %s, got %s" expected
       (if is_nullish v then "null or undefined" else typeof v))

let js v = v
let unit _ = ()

let string v =
  if typeof v = "string" then Js.to_string (Js.Unsafe.coerce v)
  else fail "string" v

let float v =
  if typeof v = "number" then Js.float_of_number (Js.Unsafe.coerce v)
  else fail "number" v

let int v =
  let f = float v in
  if not (Float.is_integer f) then
    invalid_arg "Workero.Decode: expected an integer, got a fraction"
  else if f < Float.of_int min_int || f >= -.Float.of_int min_int then
    invalid_arg "Workero.Decode: integer is outside the OCaml int range"
  else int_of_float f

let bool v =
  if typeof v = "boolean" then Js.to_bool (Js.Unsafe.coerce v)
  else fail "boolean" v

let bytes v =
  let uint8 args =
    Typed_array.String.of_uint8Array
      (Js.Unsafe.new_obj (global "Uint8Array") args)
  in
  if typeof v <> "object" || is_nullish v then fail "bytes" v
  else if Js.to_bool (meth (global "ArrayBuffer") "isView" [| v |]) then
    uint8
      [|
        Js.Unsafe.get v "buffer";
        Js.Unsafe.get v "byteOffset";
        Js.Unsafe.get v "byteLength";
      |]
  else if instance_of v (global "ArrayBuffer") then uint8 [| v |]
  else if instance_of v (global "Array") then (
    let n = int_of_js (Js.Unsafe.get v "length") in
    for i = 0 to n - 1 do
      let b = Js.Unsafe.get v i in
      if
        typeof b <> "number"
        || (not (Float.is_integer (Js.float_of_number (Js.Unsafe.coerce b))))
        || int_of_js b < 0
        || int_of_js b > 255
      then
        invalid_arg
          (Printf.sprintf
             "Workero.Decode: expected a byte (0 to 255) at index %d of the \
              array"
             i)
    done;
    uint8 [| v |])
  else fail "bytes" v

let option d v = if is_nullish v then None else Some (d v)

let list d v =
  if typeof v = "object" && instance_of v (global "Array") then
    List.init
      (int_of_js (Js.Unsafe.get v "length"))
      (fun i -> d (Js.Unsafe.get v i))
  else fail "array" v

let field name d v =
  if (typeof v = "object" || typeof v = "function") && not (is_nullish v) then
    d (Js.Unsafe.get v name)
  else fail "object" v
