module Js = Js_of_ocaml.Js
module Typed_array = Js_of_ocaml.Typed_array
open Internal

type t = js
type info = { size : int; etag : string; content_type : string option }

let of_env env name =
  Binding.of_env ~who:"Workero.R2.of_env" ~what:"an R2 bucket"
    ~methods:[ "get"; "put"; "head"; "delete" ]
    env name

let get bucket key =
  Option.map
    (fun obj ->
      let buffer : Typed_array.arrayBuffer Js.t =
        Binding.call obj "arrayBuffer" [||]
      in
      Typed_array.String.of_arrayBuffer buffer)
    (Binding.call_opt bucket "get" [| str key |])

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
  let _ : js =
    Binding.call bucket "put"
      (Array.of_list (str key :: Message.body_of_string bytes :: options))
  in
  ()

let delete bucket key =
  let _ : js = Binding.call bucket "delete" [| str key |] in
  ()

let head bucket key =
  Option.map
    (fun obj ->
      let metadata : js Js.opt = Js.Unsafe.get obj "httpMetadata" in
      {
        size = int_of_js (Js.Unsafe.get obj "size");
        etag = Js.to_string (Js.Unsafe.get obj "etag");
        content_type =
          Option.bind (Js.Opt.to_option metadata) (fun m ->
              get_string m "contentType");
      })
    (Binding.call_opt bucket "head" [| str key |])
