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

let statement db sql params =
  let stmt = Binding.invoke db "prepare" [| str sql |] in
  match params with
  | [] -> stmt
  | _ ->
      Binding.invoke stmt "bind"
        (Array.of_list (List.map Sql_value.to_js params))

let rows_of_raw raw =
  match Decode.(list (list Sql_value.of_js)) raw with
  | [] -> []
  | names :: rows ->
      let name = function
        | Sql_value.Text n -> n
        | _ -> invalid_arg "Workero.D1.query: a column name is not text"
      in
      let names = List.map name names in
      let width = List.length names in
      List.map
        (fun row ->
          if List.length row <> width then
            invalid_arg
              "Workero.D1.query: a row and the column names differ in length";
          List.combine names row)
        rows

let query ?(params = []) db sql =
  let options =
    Binding.options [ ("columnNames", Js.Unsafe.inject Js._true) ]
  in
  Binding.call ~decode:rows_of_raw (statement db sql params) "raw" [| options |]

let run ?(params = []) db sql =
  let decode = Decode.(field "meta" (field "changes" int)) in
  Binding.call ~decode (statement db sql params) "run" [||]
