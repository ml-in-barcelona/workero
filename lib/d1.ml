module Js = Js_of_ocaml.Js
open Internal

type t = js

type value = Sql_value.t =
  | Null
  | Int of int64
  | Float of float
  | Text of string
  | Blob of string

type row = (string * value) list

let of_env env name =
  Binding.of_env ~who:"Workero.D1.of_env" ~what:"a D1 database"
    ~methods:[ "prepare" ] env name

let row_of_js names (row : js) : row =
  List.mapi (fun i name -> (name, Sql_value.of_js (Js.Unsafe.get row i))) names

let statement db sql params =
  let stmt = Binding.invoke db "prepare" [| str sql |] in
  match params with
  | [] -> stmt
  | _ ->
      Binding.invoke stmt "bind"
        (Array.of_list (List.map Sql_value.to_js params))

let query ?(params = []) db sql =
  let options =
    Binding.options [ ("columnNames", Js.Unsafe.inject Js._true) ]
  in
  let result : js =
    Binding.call (statement db sql params) "raw" [| options |]
  in
  match Binding.array_to_list (fun row -> row) result with
  | [] -> []
  | names :: rows ->
      let names =
        Binding.array_to_list (fun n -> Js.to_string (Js.Unsafe.coerce n)) names
      in
      List.map (row_of_js names) rows

let run ?(params = []) db sql =
  let result : js = Binding.call (statement db sql params) "run" [||] in
  int_of_js (Js.Unsafe.get (Js.Unsafe.get result "meta") "changes")
