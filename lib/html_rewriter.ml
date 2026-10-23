module Js = Js_of_ocaml.Js
open Internal

type t = js
type content = Text of string | Html of string

let create () = Js.Unsafe.new_obj (global "HTMLRewriter") [||]

let content_args = function
  | Text s -> [| str s |]
  | Html s ->
      [| str s; Js.Unsafe.obj [| ("html", Js.Unsafe.inject Js._true) |] |]

let unit_call node name args =
  ignore (Binding.invoke node name args);
  ()

let with_content name node c = unit_call node name (content_args c)
let no_args name node = unit_call node name [||]
let bool_field node name = Js.to_bool (Js.Unsafe.get node name)
let set_string node name v = Js.Unsafe.set node name (str v)
let opt_string node name = Decode.(option string) (Js.Unsafe.get node name)

let fiber f : js =
  Async.promising (fun node ->
      Async.run (fun () ->
          f node;
          Js.Unsafe.inject Js.undefined))

module End_tag = struct
  type t = js

  let name t = Decode.string (Js.Unsafe.get t "name")
  let set_name t v = set_string t "name" v
  let before = with_content "before"
  let after = with_content "after"
  let remove = no_args "remove"
end

module Element = struct
  type t = js

  let tag_name t = Decode.string (Js.Unsafe.get t "tagName")
  let set_tag_name t v = set_string t "tagName" v
  let namespace_uri t = Decode.string (Js.Unsafe.get t "namespaceURI")
  let removed t = bool_field t "removed"

  let attributes t =
    let all : js =
      meth (global "Array") "from" [| Js.Unsafe.get t "attributes" |]
    in
    let pair p =
      (Decode.string (Js.Unsafe.get p 0), Decode.string (Js.Unsafe.get p 1))
    in
    Decode.list pair all

  let get_attribute t name =
    Decode.(option string) (Binding.invoke t "getAttribute" [| str name |])

  let has_attribute t name =
    Js.to_bool (Binding.invoke t "hasAttribute" [| str name |])

  let set_attribute t name v = unit_call t "setAttribute" [| str name; str v |]
  let remove_attribute t name = unit_call t "removeAttribute" [| str name |]
  let before = with_content "before"
  let after = with_content "after"
  let prepend = with_content "prepend"
  let append = with_content "append"
  let replace = with_content "replace"
  let set_inner_content = with_content "setInnerContent"
  let remove = no_args "remove"
  let remove_and_keep_content = no_args "removeAndKeepContent"
  let on_end_tag t f = unit_call t "onEndTag" [| fiber f |]
end

module Text_chunk = struct
  type t = js

  let text t = Decode.string (Js.Unsafe.get t "text")
  let last_in_text_node t = bool_field t "lastInTextNode"
  let removed t = bool_field t "removed"
  let before = with_content "before"
  let after = with_content "after"
  let replace = with_content "replace"
  let remove = no_args "remove"
end

module Comment = struct
  type t = js

  let text t = Decode.string (Js.Unsafe.get t "text")
  let set_text t v = set_string t "text" v
  let removed t = bool_field t "removed"
  let before = with_content "before"
  let after = with_content "after"
  let replace = with_content "replace"
  let remove = no_args "remove"
end

module Doctype = struct
  type t = js

  let name t = opt_string t "name"
  let public_id t = opt_string t "publicId"
  let system_id t = opt_string t "systemId"
end

module Document_end = struct
  type t = js

  let append = with_content "append"
end

let handlers ~who fields =
  match List.filter_map Fun.id fields with
  | [] -> invalid_arg (who ^ ": no handler given")
  | l -> Js.Unsafe.obj (Array.of_list l)

let field name = Option.map (fun f -> (name, fiber f))

let on ?element ?text ?comments selector rw =
  let h =
    handlers ~who:"Workero.Html_rewriter.on"
      [ field "element" element; field "text" text; field "comments" comments ]
  in
  ignore (Binding.invoke rw "on" [| str selector; h |]);
  rw

let on_document ?doctype ?text ?comments ?end_ rw =
  let h =
    handlers ~who:"Workero.Html_rewriter.on_document"
      [
        field "doctype" doctype;
        field "text" text;
        field "comments" comments;
        field "end" end_;
      ]
  in
  ignore (Binding.invoke rw "onDocument" [| h |]);
  rw

let transform rw res =
  Response.of_js (Binding.invoke rw "transform" [| Response.to_js res |])
