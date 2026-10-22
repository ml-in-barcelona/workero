open Internal

type t = js

let var env name = get_string env name

let secret env name =
  if not (has_own env name) then
    invalid_arg (Printf.sprintf "Workero.Env.secret: %S not found" name);
  match get_string env name with
  | Some value -> value
  | None ->
      invalid_arg
        (Printf.sprintf "Workero.Env.secret: %S is %s, not a string" name
           (describe (Js.Unsafe.get env name)))

let json env name =
  if not (has_own env name) then None
  else
    let v = Js.Unsafe.get env name in
    if typeof v = "object" && not (is_nullish v) then Some (Json_js.of_js v)
    else None

let of_js (v : js) : t = v
let to_js (t : t) : js = t
