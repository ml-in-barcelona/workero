include Url_core
open Internal

let of_string s = of_js (str s)
let field t name = Option.value (get_string t name) ~default:""
let to_string t = field t "href"
let is_secure t = String.equal (field t "protocol") "https:"
let scheme t = if is_secure t then "https" else "http"
let host t = field t "hostname"

let port t =
  match int_of_string_opt (field t "port") with
  | Some p -> p
  | None -> if is_secure t then 443 else 80

let path t =
  let raw = field t "pathname" in
  if String.contains raw '%' then
    try
      Js.to_string
        (Js.Unsafe.coerce (call (global "decodeURIComponent") [| str raw |]))
    with Js.Js_error.Exn _ -> raw
  else raw

let pathname t = field t "pathname"
let search t = field t "search"
let hash t = field t "hash"
let origin t = field t "origin"
let params t = Js.Unsafe.get t "searchParams"

let strings_of_array a =
  Array.to_list (Js.to_array (Js.Unsafe.coerce a))
  |> List.map (fun v -> Js.to_string (Js.Unsafe.coerce v))

let query t name =
  let v = meth (params t) "get" [| str name |] in
  if is_nullish v then None else Some (Js.to_string (Js.Unsafe.coerce v))

let query_all t name =
  strings_of_array (meth (params t) "getAll" [| str name |])

let query_args t =
  let pairs =
    call
      (Js.Unsafe.get (global "Array") "from")
      [| meth (params t) "entries" [||] |]
  in
  Array.to_list (Js.to_array (Js.Unsafe.coerce pairs))
  |> List.map (fun p ->
      match strings_of_array p with [ k; v ] -> (k, v) | _ -> assert false)
