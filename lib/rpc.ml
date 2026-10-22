module Js = Js_of_ocaml.Js
open Internal

type t =
  [ `Undefined
  | `Null
  | `Bool of bool
  | `Int of int
  | `Float of float
  | `String of string
  | `List of t list
  | `Assoc of (string * t) list
  | `Bytes of string
  | `Date of float
  | `Bigint of string
  | `Map of (t * t) list
  | `Set of t list
  | `Stream of Stream.t
  | `Stub of Fetcher.t
  | `Function of t list -> t ]

type value =
  [ `Undefined
  | `Null
  | `Bool of bool
  | `Int of int
  | `Float of float
  | `String of string
  | `List of value list
  | `Assoc of (string * value) list
  | `Bytes of string
  | `Date of float
  | `Bigint of string
  | `Map of (value * value) list
  | `Set of value list ]

let rec of_json : Jsonkit.t -> t = function
  | (`Null | `Bool _ | `Int _ | `Float _ | `String _) as v -> v
  | `List l -> `List (List.map of_json l)
  | `Assoc l -> `Assoc (List.map (fun (k, v) -> (k, of_json v)) l)

let rec to_json : t -> Jsonkit.t = function
  | (`Null | `Bool _ | `Int _ | `Float _ | `String _) as v -> v
  | `List l -> `List (List.map to_json l)
  | `Assoc l -> `Assoc (List.map (fun (k, v) -> (k, to_json v)) l)
  | v ->
      let name =
        match v with
        | `Undefined -> "`Undefined"
        | `Bytes _ -> "`Bytes"
        | `Date _ -> "`Date"
        | `Bigint _ -> "`Bigint"
        | `Map _ -> "`Map"
        | `Set _ -> "`Set"
        | `Stream _ -> "`Stream"
        | `Stub _ -> "`Stub"
        | `Function _ -> "`Function"
        | _ -> assert false
      in
      invalid_arg ("Workero.Rpc.to_json: " ^ name ^ " has no JSON form")

let rec to_value : t -> value = function
  | ( `Undefined | `Null | `Bool _ | `Int _ | `Float _ | `String _ | `Bytes _
    | `Date _ | `Bigint _ ) as v ->
      v
  | `List l -> `List (List.map to_value l)
  | `Assoc l -> `Assoc (List.map (fun (k, v) -> (k, to_value v)) l)
  | `Map l -> `Map (List.map (fun (k, v) -> (to_value k, to_value v)) l)
  | `Set l -> `Set (List.map to_value l)
  | (`Stream _ | `Stub _ | `Function _) as v ->
      let name =
        match v with
        | `Stream _ -> "`Stream"
        | `Stub _ -> "`Stub"
        | `Function _ -> "`Function"
      in
      invalid_arg ("Workero.Rpc.to_value: " ^ name ^ " is not a plain value")

let unsupported what =
  invalid_arg ("Workero.Rpc.of_js: unsupported JavaScript value: " ^ what)

let number f = Js.Unsafe.inject (Js.number_of_float f)
let array l = Js.Unsafe.inject (Js.array (Array.of_list l))
let to_float v = Js.float_of_number (Js.Unsafe.coerce v)
let to_string v = Js.to_string (Js.Unsafe.coerce v)

let tag v =
  to_string
    (meth
       (Js.Unsafe.get (Js.Unsafe.get (global "Object") "prototype") "toString")
       "call" [| v |])

let elements v =
  let all = meth (global "Array") "from" [| v |] in
  List.init
    (int_of_js (Js.Unsafe.get all "length"))
    (fun i -> Js.Unsafe.get all i)

let int_of_number f =
  if
    Float.is_integer f
    && f >= float_of_int min_int
    && f < float_of_int max_int
    && not (f = 0. && 1. /. f < 0.)
  then Some (int_of_float f)
  else None

let max_depth = 1000

let is_plain v =
  let proto = meth (global "Object") "getPrototypeOf" [| v |] in
  is_nullish proto
  || js_equals proto (Js.Unsafe.get (global "Object") "prototype")

let rec read depth v : t =
  if depth > max_depth then
    invalid_arg "Workero.Rpc.of_js: the value is cyclic or nested too deeply";
  match typeof v with
  | "undefined" -> `Undefined
  | "boolean" -> `Bool (Decode.bool v)
  | "string" -> `String (to_string v)
  | "number" -> (
      let f = to_float v in
      match int_of_number f with Some n -> `Int n | None -> `Float f)
  | "bigint" -> `Bigint (to_string (call (global "String") [| v |]))
  | "function" -> `Function (stub_function depth v)
  | "object" when is_nullish v -> `Null
  | "object" -> (
      let items () = List.map (read (depth + 1)) (elements v) in
      match tag v with
      | "[object Array]" -> `List (items ())
      | "[object Uint8Array]" | "[object ArrayBuffer]" ->
          `Bytes (Decode.bytes v)
      | "[object Date]" -> `Date (to_float (meth v "getTime" [||]))
      | "[object Set]" -> `Set (items ())
      | "[object Map]" ->
          `Map
            (List.map
               (fun pair ->
                 ( read (depth + 1) (Js.Unsafe.get pair 0),
                   read (depth + 1) (Js.Unsafe.get pair 1) ))
               (elements (meth v "entries" [||])))
      | "[object ReadableStream]" -> `Stream (Stream.of_js v)
      | "[object Fetcher]" -> `Stub (Fetcher.of_js v)
      | "[object Object]" when is_plain v ->
          `Assoc
            (List.map
               (fun pair ->
                 ( to_string (Js.Unsafe.get pair 0),
                   read (depth + 1) (Js.Unsafe.get pair 1) ))
               (elements (meth (global "Object") "entries" [| v |])))
      | other -> unsupported other)
  | other -> unsupported other

and stub_function depth f args =
  let args = array (List.map to_js args) in
  Promise.await
    (Promise.of_js ~decode:(read depth)
       (Binding.invoke (global "Reflect") "apply"
          [| f; Js.Unsafe.inject Js.undefined; args |]))

and to_js : t -> js = function
  | `Undefined -> Js.Unsafe.inject Js.undefined
  | `Null -> null
  | `Bool b -> Js.Unsafe.inject (Js.bool b)
  | `Int n -> number (float_of_int n)
  | `Float f -> number f
  | `String s -> str s
  | `List l -> array (List.map to_js l)
  | `Assoc l ->
      meth (global "Object") "fromEntries"
        [| array (List.map (fun (k, v) -> array [ str k; to_js v ]) l) |]
  | `Bytes s -> Wire.body_of_string s
  | `Date ms -> Js.Unsafe.new_obj (global "Date") [| number ms |]
  | `Bigint s ->
      let digits =
        if s <> "" && (s.[0] = '-' || s.[0] = '+') then
          String.sub s 1 (String.length s - 1)
        else s
      in
      if
        digits = ""
        || not
             (String.for_all
                (function '0' .. '9' -> true | _ -> false)
                digits)
      then
        invalid_arg
          (Printf.sprintf "Workero.Rpc.to_js: %S is not a decimal integer" s);
      call (global "BigInt") [| str s |]
  | `Map l ->
      Js.Unsafe.new_obj (global "Map")
        [| array (List.map (fun (k, v) -> array [ to_js k; to_js v ]) l) |]
  | `Set l -> Js.Unsafe.new_obj (global "Set") [| array (List.map to_js l) |]
  | `Stream s -> Stream.to_js s
  | `Stub f -> Fetcher.to_js f
  | `Function f -> callback f

and callback f : js =
  let run =
    Async.promising (fun args : js ->
        Async.run (fun () ->
            Fun.protect ~finally:flush_all (fun () ->
                to_js (f (List.map (read 0) (Decode.(list js) args))))))
  in
  Js.Unsafe.inject
    (Js.Unsafe.callback_with_arguments (fun arguments ->
         call run [| meth (global "Array") "from" [| arguments |] |]))

let of_js v = read 0 v

let call stub name args =
  let stub = Fetcher.to_js stub in
  let args = array (List.map to_js args) in
  Promise.await
    (Promise.of_js ~decode:of_js
       (Binding.invoke (global "Reflect") "apply"
          [| Js.Unsafe.get stub name; stub; args |]))
