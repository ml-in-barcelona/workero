module Js = Js_of_ocaml.Js
open Internal

type t = js
type info = { size : int; etag : string; content_type : string option }

let of_env env name =
  Binding.of_env ~who:"Workero.R2.of_env" ~what:"an R2 bucket"
    ~methods:[ "get"; "put"; "head"; "delete" ]
    env name

let get bucket key =
  Option.map
    (fun obj -> Binding.call ~decode:Decode.bytes obj "arrayBuffer" [||])
    (Binding.call_opt ~decode:Decode.js bucket "get" [| str key |])

let put ?content_type bucket key bytes =
  let options =
    match content_type with
    | Some ct ->
        [
          Binding.options
            [ ("httpMetadata", Binding.options [ ("contentType", str ct) ]) ];
        ]
    | None -> []
  in
  Binding.call ~decode:Decode.unit bucket "put"
    (Array.of_list (str key :: Wire.body_of_string bytes :: options))

let delete bucket key =
  Binding.call ~decode:Decode.unit bucket "delete" [| str key |]

let head bucket key =
  let decode =
    let open Decode in
    fun obj ->
      {
        size = field "size" int obj;
        etag = field "etag" string obj;
        content_type =
          field "httpMetadata"
            (option (field "contentType" (option string)))
            obj
          |> Option.join;
      }
  in
  Binding.call_opt ~decode bucket "head" [| str key |]

let of_js (v : js) : t = v
let to_js (t : t) : js = t
