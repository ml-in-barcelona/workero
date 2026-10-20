module Style = React_dom_style
module Ref = React.Ref

type dom_ref = Ref.t

let float_to_string f =
  let open Js_of_ocaml in
  Js.to_string (Js.Unsafe.meth_call (Js.number_of_float f) "toString" [||])

let is_react_custom_attribute attr =
  match attr with
  | "dangerouslySetInnerHTML" | "ref" | "key" | "suppressContentEditableWarning" | "suppressHydrationWarning" -> true
  | _ -> false

(* Writes ` name="value"` for values that need no HTML escaping (numbers, booleanish strings). *)
let write_raw_attribute buf name value =
  Buffer.add_char buf ' ';
  Buffer.add_string buf name;
  Buffer.add_string buf "=\"";
  Buffer.add_string buf value;
  Buffer.add_char buf '"'

let write_attribute_to_buffer buf (attr : React.Jsx.prop) =
  match attr with
  (* ignores "ref" prop *)
  | Ref _ -> ()
  (* react custom attributes are not rendered *)
  | Bool (name, _, _) when is_react_custom_attribute name -> ()
  (* false attributes don't get rendered *)
  | Bool (_name, _, false) -> ()
  (* true attributes render solely the attribute name *)
  | Bool (name, _, true) ->
      Buffer.add_char buf ' ';
      Buffer.add_string buf name
  | (Booleanish_string (name, _, _) | String (name, _, _) | Int (name, _, _) | Float (name, _, _))
    when is_react_custom_attribute name ->
      ()
  | Booleanish_string (name, _, value) -> write_raw_attribute buf name (if value then "true" else "false")
  | Style styles ->
      Buffer.add_string buf " style=\"";
      Html.escape buf (Style.to_string styles);
      Buffer.add_char buf '"'
  | String (name, _, value) ->
      Buffer.add_char buf ' ';
      Buffer.add_string buf name;
      Buffer.add_string buf "=\"";
      Html.escape buf value;
      Buffer.add_char buf '"'
  | Int (name, _, value) -> write_raw_attribute buf name (Int.to_string value)
  | Float (name, _, value) -> write_raw_attribute buf name (float_to_string value)
  (* Events don't get rendered on SSR *)
  | Event _ -> ()
  (* Since we extracted the attribute as children, we are sure there's nothing to render here *)
  | Dangerously_inner_html _ -> ()

let write_attributes_and_extract_inner_html buf attrs =
  let inner_html = ref None in
  List.iter
    (fun (attr : React.Jsx.prop) ->
      match attr with Dangerously_inner_html str -> inner_html := Some str | _ -> write_attribute_to_buffer buf attr)
    attrs;
  !inner_html

type mode = String | Markup

(* Text-like elements (Text, Int, Float) render as text nodes: user strings are HTML-escaped, numbers are stringified
   the way JavaScript does ("2", not OCaml's "2."). Callers handle their own text-node separator semantics. *)
let write_text_node buf (element : React.element) =
  match element with
  | Text text -> Html.escape buf text
  | Int i -> Buffer.add_string buf (Int.to_string i)
  | Float f -> Buffer.add_string buf (float_to_string f)
  | _ -> raise (Invalid_argument "write_text_node expects a Text, Int or Float element")

(* The sync tree walker behind render_to_string, render_to_static_markup and the
   ppx Writer fast path. [separators] and [prev_text] are documented on
   [write_element_to_buffer] in the mli; [doctype] is false for Writer emit
   bodies because the ppx bakes the doctype into its prerendered chunks.
   [buf] stays positional on every recursive function: partial applications
   allocate a closure per parent node (benchmark/perf-work/PERF_NEXT.md, H1). *)
let render_tree buf ~separators ~doctype ~prev_text element : bool =
  (* Render-scoped and monotonic (true until the first emitting node), so a
     single ref is simpler than threading it alongside [prev_text]. *)
  let doctype_pending = ref doctype in
  let rec render buf prev_text (element : React.element) : bool =
    match element with
    | Empty -> prev_text
    | Static { prerendered; _ } ->
        doctype_pending := false;
        (* Prerendered chunks are complete elements: they end the current text run *)
        Buffer.add_string buf prerendered;
        false
    | Writer { emit; _ } ->
        doctype_pending := false;
        emit buf ~separators;
        false
    | Provider { children; push; _ } ->
        let pop = push () in
        let ends_text = render buf prev_text children in
        pop ();
        ends_text
    | Consumer children -> render buf prev_text children
    | Fragment children -> render buf prev_text children
    | List list -> render_children_list buf prev_text list
    | Array arr -> render_children_array buf prev_text arr
    | Upper_case_component (_, component) -> render_upper_case_component buf prev_text component
    | Lower_case_element { key = _; tag; attributes; children } ->
        render_lower_case buf tag attributes children;
        false
    | (Text _ | Int _ | Float _) as text_node ->
        if prev_text && separators then Buffer.add_string buf "<!-- -->";
        write_text_node buf text_node;
        doctype_pending := false;
        true
    | Suspense { key = _; children; fallback } -> (
        let suspense_inner_buf = Buffer.create 128 in
        match render suspense_inner_buf prev_text children with
        | ends_text ->
            Buffer.add_string buf "<!--$-->";
            Buffer.add_buffer buf suspense_inner_buf;
            Buffer.add_string buf "<!--/$-->";
            ends_text
        | exception _e ->
            Buffer.add_string buf "<!--$!-->";
            let ends_text = render buf prev_text (Option.value fallback ~default:React.null) in
            Buffer.add_string buf "<!--/$-->";
            ends_text)
  and render_upper_case_component buf prev_text component =
    let saved_ctx = !React.current_tree_context in
    React.reset_component_id_state saved_ctx;
    match component () with
    | result -> (
        let did_use_id = React.check_did_render_id_hook () in
        if did_use_id then React.current_tree_context := React.Tree_context.push saved_ctx ~total_children:1 ~index:0;
        match render buf prev_text result with
        | ends_text ->
            React.current_tree_context := saved_ctx;
            ends_text
        | exception exn ->
            React.current_tree_context := saved_ctx;
            raise exn)
    | exception exn ->
        React.current_tree_context := saved_ctx;
        raise exn
  and render_children_list buf prev_text list =
    match list with
    | [] -> prev_text
    | [ single ] -> render buf prev_text single
    | _ -> (
        let saved_ctx = !React.current_tree_context in
        let total = List.length list in
        let rec go i prev_text = function
          | [] -> prev_text
          | el :: rest ->
              React.current_tree_context := React.Tree_context.push saved_ctx ~total_children:total ~index:i;
              let prev_text = render buf prev_text el in
              go (i + 1) prev_text rest
        in
        match go 0 prev_text list with
        | ends_text ->
            React.current_tree_context := saved_ctx;
            ends_text
        | exception exn ->
            React.current_tree_context := saved_ctx;
            raise exn)
  and render_children_array buf prev_text arr =
    let total = Array.length arr in
    if total = 0 then prev_text
    else if total = 1 then render buf prev_text (Array.unsafe_get arr 0)
    else
      let saved_ctx = !React.current_tree_context in
      let rec go i prev_text =
        if i = total then prev_text
        else begin
          React.current_tree_context := React.Tree_context.push saved_ctx ~total_children:total ~index:i;
          go (i + 1) (render buf prev_text (Array.unsafe_get arr i))
        end
      in
      match go 0 prev_text with
      | ends_text ->
          React.current_tree_context := saved_ctx;
          ends_text
      | exception exn ->
          React.current_tree_context := saved_ctx;
          raise exn
  and render_lower_case buf tag attributes children =
    if Html.is_self_closing_tag tag then (
      doctype_pending := false;
      Buffer.add_char buf '<';
      Buffer.add_string buf tag;
      let _ = write_attributes_and_extract_inner_html buf attributes in
      Buffer.add_string buf " />")
    else
      let doctype = !doctype_pending in
      doctype_pending := false;
      if tag = "html" && doctype then Buffer.add_string buf "<!DOCTYPE html>";
      Buffer.add_char buf '<';
      Buffer.add_string buf tag;
      let inner_html = write_attributes_and_extract_inner_html buf attributes in
      Buffer.add_char buf '>';
      (match inner_html with
      | Some html -> Buffer.add_string buf html
      | None ->
          let (_ : bool) = render_children_list buf false children in
          ());
      Buffer.add_string buf "</";
      Buffer.add_string buf tag;
      Buffer.add_char buf '>'
  in
  render buf prev_text element

let render_to_buffer ~mode buf element =
  let (_ : bool) = render_tree buf ~separators:(mode = String) ~doctype:true ~prev_text:false element in
  ()

(* Threaded String-mode write used by the ppx [React.Writer] emit bodies *)
let write_element_to_buffer buf ~separators ~prev_text element : bool =
  render_tree buf ~separators ~doctype:false ~prev_text element

let write_to_buffer buf element =
  let (_ : bool) = render_tree buf ~separators:false ~doctype:false ~prev_text:false element in
  ()

let escape_to_buffer = Html.escape

(* Steady-state SSR renders similarly-sized documents back to back. Seeding
   the render buffer with the previous render's size lets the common case
   skip the doubling-resize ladder from 1KB (each rung reallocates and
   memcpys the whole buffer so far). The clamp keeps a one-off huge render
   from pinning large allocations onto subsequent small renders. The ref is
   a heuristic: a race across domains only produces a suboptimal hint. *)
let min_render_buffer_size = 1024
let max_render_buffer_hint = 131072
let last_render_size = ref min_render_buffer_size

let remember_render_size size =
  let clamped =
    if size < min_render_buffer_size then min_render_buffer_size
    else if size > max_render_buffer_hint then max_render_buffer_hint
    else size
  in
  if clamped <> !last_render_size then last_render_size := clamped

let render_sync ~mode ?identifier_prefix element =
  (* TODO: try catch to avoid React.use usages *)
  React.reset_id_rendering ?prefix:identifier_prefix ();
  let buf = Buffer.create !last_render_size in
  render_to_buffer ~mode buf element;
  remember_render_size (Buffer.length buf);
  Buffer.contents buf

let render_to_string ?identifier_prefix element = render_sync ~mode:String ?identifier_prefix element
let render_to_static_markup ?identifier_prefix element = render_sync ~mode:Markup ?identifier_prefix element
