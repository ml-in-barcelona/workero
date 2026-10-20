module Raw = Js_of_ocaml.Url

type t = { secure : bool; url : Raw.http_url }

let of_string s =
  match Raw.url_of_string s with
  | Some (Raw.Http url) -> Some { secure = false; url }
  | Some (Raw.Https url) -> Some { secure = true; url }
  | Some (Raw.File _) | None -> None

let to_string t =
  Raw.string_of_url (if t.secure then Raw.Https t.url else Raw.Http t.url)

let scheme t = if t.secure then "https" else "http"
let host t = t.url.hu_host
let port t = t.url.hu_port
let path t = "/" ^ t.url.hu_path_string
let query_args t = t.url.hu_arguments

let query_all t name =
  List.filter_map
    (fun (k, v) -> if String.equal k name then Some v else None)
    (query_args t)

let query t name = List.assoc_opt name (query_args t)
