open Internal

type t = js
type file = js
type value = Text of string | File of file

let value v : value =
  if typeof v = "string" then Text (Decode.string v) else File v

let array_to_list f arr =
  let all : js = meth (global "Array") "from" [| arr |] in
  List.init
    (int_of_js (Js.Unsafe.get all "length"))
    (fun i -> f (Js.Unsafe.get all i))

let get t name =
  let v = Binding.invoke t "get" [| str name |] in
  if is_nullish v then None else Some (value v)

let get_all t name =
  array_to_list value (Binding.invoke t "getAll" [| str name |])

let to_list t =
  array_to_list
    (fun pair ->
      (Decode.string (Js.Unsafe.get pair 0), value (Js.Unsafe.get pair 1)))
    (Binding.invoke t "entries" [||])

let file_name f = Decode.(field "name" string) f
let file_type f = Decode.(field "type" string) f
let file_size f = Decode.(field "size" int) f
let file_bytes f = Binding.call ~decode:Decode.bytes f "arrayBuffer" [||]
let file_stream f = Stream.of_js (Binding.invoke f "stream" [||])
let of_js (v : js) : t = v
let to_js (t : t) : js = t
