open Ppxlib
open Ast_builder.Default
module List = ListLabels

let repo_url = "https://github.com/ml-in-barcelona/server-reason-react"
let issues_url = Printf.sprintf "%s/issues" repo_url

(* There's no Ppxlib.pexp_list since isn't a parsetree constructor *)
let pexp_list ~loc xs =
  List.fold_left (List.rev xs) ~init:[%expr []] ~f:(fun xs x ->
      let loc = x.pexp_loc in
      [%expr [%e x] :: [%e xs]])

exception Error of expression

let raise_errorf ~loc fmt =
  Printf.ksprintf
    (fun msg ->
      let expr = pexp_extension ~loc (Location.error_extensionf ~loc "%s" msg) in
      raise (Error expr))
    fmt

let longident ~loc txt = { txt = Lident txt; loc }
let ident ~loc txt = pexp_ident ~loc (longident ~loc txt)
let make_string ~loc str = Ast_helper.Exp.constant ~loc (Ast_helper.Const.string str)
let react_dot_component = "react.component"
let has_attr { attr_name; _ } comparable = attr_name.txt = comparable
let has_any_react_component_attribute { attr_name; _ } = attr_name.txt = react_dot_component
let non_react_attributes { attr_name; _ } = attr_name.txt <> react_dot_component

let has_attr_on_binding { pvb_attributes } comparable =
  List.find_opt ~f:(fun attr -> has_attr attr comparable) pvb_attributes <> None

let is_react_component_binding vb = has_attr_on_binding vb react_dot_component

let rec unwrap_children children = function
  | { pexp_desc = Pexp_construct ({ txt = Lident "[]"; _ }, None); _ } -> List.rev children
  | { pexp_desc = Pexp_construct ({ txt = Lident "::"; _ }, Some { pexp_desc = Pexp_tuple [ child; next ]; _ }); _ } ->
      unwrap_children (child :: children) next
  | e -> raise_errorf ~loc:e.pexp_loc "jsx: children prop should be a list"

let is_jsx = function { attr_name = { txt = "JSX"; _ }; _ } -> true | _ -> false
let has_jsx_attr attrs = List.exists ~f:is_jsx attrs

let strip_unit_args args =
  List.filter args ~f:(fun (label, expr) ->
      match (label, expr.pexp_desc) with Nolabel, Pexp_construct ({ txt = Lident "()"; _ }, None) -> false | _ -> true)

let component_make_props_ident tag =
  match tag with
  | { txt = Lident name; loc } -> { txt = Lident (name ^ "_props"); loc }
  | { txt = Ldot (path, name); loc } -> { txt = Ldot (path, name ^ "_props"); loc }
  | { txt = Lapply _; loc } -> raise_errorf ~loc "jsx: component props can't be created from functor applications"

let is_key_arg (label, _) = match label with Optional "key" | Labelled "key" -> true | _ -> false

let rewrite_component ~loc tag args children =
  let component = pexp_ident ~loc tag in
  let props_args =
    match children with
    | None -> args
    | Some [ children ] -> (Labelled "children", children) :: args
    | Some children -> (Labelled "children", [%expr React.list [%e pexp_list ~loc children]]) :: args
  in
  let key_args, non_key_args = List.partition ~f:is_key_arg props_args in
  let make_props = pexp_ident ~loc (component_make_props_ident tag) in
  let non_key_args = strip_unit_args non_key_args in
  let props = pexp_apply ~loc make_props (non_key_args @ [ (Nolabel, [%expr ()]) ]) in
  let make_args =
    match key_args with [] -> [ (Nolabel, props) ] | (label, expr) :: _ -> [ (label, expr); (Nolabel, props) ]
  in
  pexp_apply ~loc component make_args

let validate_prop ~loc id name =
  match Dom_props.find_by_jsx_name ~tag:id name with
  | Ok p -> p
  | Error `Element_not_found ->
      raise_errorf ~loc "jsx: HTML tag '%s' doesn't exist.\nIf this isn't correct, please open an issue at %s" id
        issues_url
  | Error `Attribute_not_found -> (
      match Dom_props.find_closest_name name with
      | None ->
          raise_errorf ~loc
            "jsx: prop '%s' isn't valid on a '%s' element.\nIf this isn't correct, please open an issue at %s." name id
            issues_url
      | Some suggestion ->
          raise_errorf ~loc
            "jsx: prop '%s' isn't valid on a '%s' element.\n\
             Hint: Maybe you mean '%s'?\n\n\
             If this isn't correct, please open an issue at %s."
            name id suggestion issues_url)

let make_prop ~is_optional ~prop attribute_value =
  let loc = attribute_value.pexp_loc in
  let open Dom_props in
  match (prop, is_optional) with
  | Attribute { type_ = Dom_props.String; name; jsx_name }, false ->
      [%expr
        Some (React.Jsx.String ([%e estring ~loc name], [%e estring ~loc jsx_name], ([%e attribute_value] : string)))]
  | Attribute { type_ = Dom_props.String; name; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : string option) with
        | None -> None
        | Some v -> Some (React.Jsx.String ([%e estring ~loc name], [%e estring ~loc jsx_name], v))]
  | Attribute { type_ = Dom_props.Int; name; jsx_name }, false ->
      [%expr Some (React.Jsx.Int ([%e estring ~loc name], [%e estring ~loc jsx_name], ([%e attribute_value] : int)))]
  | Attribute { type_ = Dom_props.Int; name; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : int option) with
        | None -> None
        | Some v -> Some (React.Jsx.Int ([%e estring ~loc name], [%e estring ~loc jsx_name], v))]
  | Attribute { type_ = Dom_props.Float; name; jsx_name }, false ->
      [%expr
        Some (React.Jsx.Float ([%e estring ~loc name], [%e estring ~loc jsx_name], ([%e attribute_value] : float)))]
  | Attribute { type_ = Dom_props.Float; name; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : float option) with
        | None -> None
        | Some v -> Some (React.Jsx.Float ([%e estring ~loc name], [%e estring ~loc jsx_name], v))]
  | Attribute { type_ = Dom_props.Bool; name; jsx_name }, false ->
      [%expr Some (React.Jsx.Bool ([%e estring ~loc name], [%e estring ~loc jsx_name], ([%e attribute_value] : bool)))]
  | Attribute { type_ = Dom_props.Bool; name; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : bool option) with
        | None -> None
        | Some v -> Some (React.Jsx.Bool ([%e estring ~loc name], [%e estring ~loc jsx_name], v))]
  (* Booleanish_string stays a boolean until the serialization seams: HTML renders "true"/"false", Flight keeps the raw
     JSON boolean *)
  | Attribute { type_ = Dom_props.Booleanish_string; name; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Booleanish_string
             ([%e estring ~loc name], [%e estring ~loc jsx_name], ([%e attribute_value] : bool)))]
  | Attribute { type_ = Dom_props.Booleanish_string; name; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : bool option) with
        | None -> None
        | Some v -> Some (React.Jsx.Booleanish_string ([%e estring ~loc name], [%e estring ~loc jsx_name], v))]
  | Attribute { type_ = Dom_props.Style; _ }, false ->
      [%expr Some (React.Jsx.Style ([%e attribute_value] : React_dom.Style.t))]
  | Attribute { type_ = Dom_props.Style; _ }, true ->
      [%expr
        match ([%e attribute_value] : React_dom.Style.t option) with None -> None | Some v -> Some (React.Jsx.Style v)]
  | Attribute { type_ = Dom_props.Ref; _ }, false -> [%expr Some (React.Jsx.Ref ([%e attribute_value] : React.dom_ref))]
  | Attribute { type_ = Dom_props.Ref; _ }, true ->
      [%expr match ([%e attribute_value] : React.dom_ref option) with None -> None | Some v -> Some (React.Jsx.Ref v)]
  | Attribute { type_ = Dom_props.Inner_html; _ }, false ->
      [%expr Some (React.Jsx.dangerously_inner_html [%e attribute_value])]
  | Attribute { type_ = Dom_props.Inner_html; _ }, true ->
      [%expr match [%e attribute_value] with None -> None | Some v -> Some (React.Jsx.dangerously_inner_html v)]
  | Event { type_ = Mouse; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ([%e make_string ~loc jsx_name], React.Jsx.Mouse ([%e attribute_value] : React.Event.Mouse.t -> unit)))]
  | Event { type_ = Mouse; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Mouse.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Mouse v))]
  | Event { type_ = Selection; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ([%e make_string ~loc jsx_name], React.Jsx.Selection ([%e attribute_value] : React.Event.Mouse.t -> unit)))]
  | Event { type_ = Selection; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Selection.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Selection v))]
  | Event { type_ = Touch; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ([%e make_string ~loc jsx_name], React.Jsx.Touch ([%e attribute_value] : React.Event.Touch.t -> unit)))]
  | Event { type_ = Touch; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Touch.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Touch v))]
  | Event { type_ = Ui; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ([%e make_string ~loc jsx_name], React.Jsx.Ui ([%e attribute_value] : React.Event.Ui.t -> unit)))]
  | Event { type_ = Ui; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Ui.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Ui v))]
  | Event { type_ = Wheel; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ([%e make_string ~loc jsx_name], React.Jsx.Wheel ([%e attribute_value] : React.Event.Wheel.t -> unit)))]
  | Event { type_ = Wheel; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Wheel.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Wheel v))]
  | Event { type_ = Clipboard; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ( [%e make_string ~loc jsx_name],
               React.Jsx.Clipboard ([%e attribute_value] : React.Event.Clipboard.t -> unit) ))]
  | Event { type_ = Clipboard; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Clipboard.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Clipboard v))]
  | Event { type_ = Composition; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ( [%e make_string ~loc jsx_name],
               React.Jsx.Composition ([%e attribute_value] : React.Event.Composition.t -> unit) ))]
  | Event { type_ = Composition; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Composition.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Composition v))]
  | Event { type_ = Keyboard; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ([%e make_string ~loc jsx_name], React.Jsx.Keyboard ([%e attribute_value] : React.Event.Keyboard.t -> unit)))]
  | Event { type_ = Keyboard; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Keyboard.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Keyboard v))]
  | Event { type_ = Focus; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ([%e make_string ~loc jsx_name], React.Jsx.Focus ([%e attribute_value] : React.Event.Focus.t -> unit)))]
  | Event { type_ = Focus; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Focus.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Focus v))]
  | Event { type_ = Form; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ([%e make_string ~loc jsx_name], React.Jsx.Form ([%e attribute_value] : React.Event.Form.t -> unit)))]
  | Event { type_ = Form; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Form.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Form v))]
  | Event { type_ = Media; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ([%e make_string ~loc jsx_name], React.Jsx.Media ([%e attribute_value] : React.Event.Media.t -> unit)))]
  | Event { type_ = Media; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Media.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Media v))]
  | Event { type_ = Inline; jsx_name }, false ->
      [%expr Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Inline ([%e attribute_value] : string)))]
  | Event { type_ = Inline; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : string option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Inline v))]
  | Event { type_ = Image; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ( [%e make_string ~loc jsx_name],
               React.Jsx.Image ([%e attribute_value] : (React.Event.Image.t -> unit) option) ))]
  | Event { type_ = Image; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Image.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Image v))]
  | Event { type_ = Animation; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ( [%e make_string ~loc jsx_name],
               React.Jsx.Animation ([%e attribute_value] : React.Event.Animation.t -> unit) ))]
  | Event { type_ = Animation; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Animation.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Animation v))]
  | Event { type_ = Transition; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ( [%e make_string ~loc jsx_name],
               React.Jsx.Transition ([%e attribute_value] : React.Event.Transition.t -> unit) ))]
  | Event { type_ = Transition; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Transition.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Transition v))]
  | Event { type_ = Pointer; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ([%e make_string ~loc jsx_name], React.Jsx.Pointer ([%e attribute_value] : React.Event.Pointer.t -> unit)))]
  | Event { type_ = Pointer; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Pointer.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Pointer v))]
  | Event { type_ = Drag; jsx_name }, false ->
      [%expr
        Some
          (React.Jsx.Event
             ([%e make_string ~loc jsx_name], React.Jsx.Drag ([%e attribute_value] : React.Event.Drag.t -> unit)))]
  | Event { type_ = Drag; jsx_name }, true ->
      [%expr
        match ([%e attribute_value] : (React.Event.Drag.t -> unit) option) with
        | None -> None
        | Some v -> Some (React.Jsx.Event ([%e make_string ~loc jsx_name], React.Jsx.Drag v))]

let is_optional = function Optional _ -> true | _ -> false
let get_label = function Nolabel -> "" | Optional name | Labelled name -> name

let transform_labelled ~loc ~tag_name (prop_label, (runtime_value : expression)) props =
  match prop_label with
  | Nolabel -> props
  | Optional name | Labelled name ->
      let is_optional = is_optional prop_label in
      let prop = validate_prop ~loc tag_name name in
      let new_prop = make_prop ~is_optional ~prop runtime_value in
      [%expr [%e new_prop] :: [%e props]]

let transform_lowercase_props ~loc ~tag_name args =
  match args with
  | [] -> [%expr []]
  | attrs -> (
      let list_of_attributes = attrs |> List.fold_right ~f:(transform_labelled ~loc ~tag_name) ~init:[%expr []] in
      match list_of_attributes with
      | [%expr []] -> [%expr []]
      | _ ->
          (* We need to filter attributes since optionals are represented as None *)
          [%expr Stdlib.List.filter_map Stdlib.Fun.id [%e list_of_attributes]])

let generate_create_element ~loc ~tag_name ~key ~props ~children =
  let dom_node_name = estring ~loc tag_name in
  match (key, children) with
  | Some key, Some children ->
      let childrens = pexp_list ~loc children in
      [%expr React.create_element_with_key ~key:[%e key] [%e dom_node_name] [%e props] [%e childrens]]
  | None, Some children ->
      let childrens = pexp_list ~loc children in
      [%expr React.create_element [%e dom_node_name] [%e props] [%e childrens]]
  | Some key, None -> [%expr React.create_element_with_key ~key:[%e key] [%e dom_node_name] [%e props] []]
  | None, None -> [%expr React.create_element [%e dom_node_name] [%e props] []]

(* Emit buffer writes that serialize a single attribute value of the given
   kind. Mirrors [React_dom.write_attribute_to_buffer] exactly so that PPX-
   lowered output is byte-identical to the variant-tree path.

   [value_expr] is the already-unwrapped (not an option) runtime expression
   that produces the value. Handles only the kinds declared lowerable in
   [Static_analysis.is_lowerable_kind]. Mirrored by
   [Static_analysis.render_static_attr_with_info] on the literal side. *)
let emit_attr_value_write ~loc ~info ~value_expr =
  let open Static_analysis in
  let name_expr = estring ~loc info.html_name in
  (* Wrap a value-writing sub-expression with the ` name="…"` skeleton. *)
  let quoted inner =
    [%expr
      Buffer.add_char __buf ' ';
      Buffer.add_string __buf [%e name_expr];
      Buffer.add_string __buf "=\"";
      [%e inner];
      Buffer.add_char __buf '"']
  in
  match info.kind with
  | Dom_props.String -> quoted [%expr React_dom.escape_to_buffer __buf ([%e value_expr] : string)]
  | Dom_props.Int ->
      (* [string_of_int] allocates a small short-lived string, but measures
         ~15% faster per write than [Printf.bprintf b "%d"], whose
         CamlinternalFormat dispatch outweighs the allocation it saves. *)
      quoted [%expr Buffer.add_string __buf (Stdlib.string_of_int ([%e value_expr] : int))]
  | Dom_props.Bool ->
      (* Matches [Bool (name, _, true) -> " " ^ name] / [false -> nothing]. *)
      [%expr
        if ([%e value_expr] : bool) then begin
          Buffer.add_char __buf ' ';
          Buffer.add_string __buf [%e name_expr]
        end]
  | Dom_props.Booleanish_string ->
      quoted [%expr Buffer.add_string __buf (if ([%e value_expr] : bool) then "true" else "false")]
  | Dom_props.Style ->
      (* Mirrors [React_dom.write_attribute_to_buffer]'s [Style] case exactly:
         serialize the style, then HTML-escape the result (so a quoted value
         such as a [font-family] cannot break out of the [style="…"] attribute),
         byte-identical output. *)
      [%expr
        Buffer.add_string __buf " style=\"";
        React_dom.escape_to_buffer __buf (React_dom.Style.to_string ([%e value_expr] : React_dom.Style.t));
        Buffer.add_char __buf '"']
  | Dom_props.Float | Dom_props.Ref | Dom_props.Inner_html ->
      (* Unreachable: [is_lowerable_kind] rejects these kinds before we ever
         reach emission. Fail loud at compile time if the invariant breaks. *)
      Location.raise_errorf ~loc "internal PPX error: attribute kind not lowerable but reached emission (name=%s)"
        info.html_name

(* The concrete (non-option) value type carried by a lowerable attribute
   kind. Used to annotate an optional attribute's scrutinee as
   [(expr : t option)] so OCaml's type-directed disambiguation resolves a
   bare [None]/[Some] in [expr] against [option] — even when a user type in
   scope shadows them (e.g. [type roundness = … | None]). This mirrors the
   annotations the variant-tree path emits in [make_prop]; without it the
   [Writer.emit] fast path is the only place that loses the expected type. *)
let attr_value_core_type ~loc (kind : Dom_props.attribute_type) =
  match kind with
  | Dom_props.String -> [%type: string]
  | Dom_props.Int -> [%type: int]
  | Dom_props.Bool | Dom_props.Booleanish_string -> [%type: bool]
  | Dom_props.Style -> [%type: React_dom.Style.t]
  | Dom_props.Float | Dom_props.Ref | Dom_props.Inner_html ->
      (* Unreachable for the same reason as [emit_attr_value_write]. *)
      Location.raise_errorf ~loc "internal PPX error: attribute kind not lowerable but reached emission"

(* Compile-time knowledge of whether the previously emitted node ended
   inside a text run. [Ct_unknown] appears only after a [Dynamic_element]
   hole, whose content is decided at render time. *)
type compile_time_textness = Ct_text | Ct_markup | Ct_unknown

(* Emit the [Buffer.t -> separators:bool -> unit] body for a
   [static_part list]. Writes the static skeleton inline; each dynamic hole
   becomes a [Buffer.add_*] / escape / attribute-emission call that runs at
   render time with no intermediate allocation. Shared by the
   [Needs_string_concat] and [Needs_buffer] tiers, which produce the same
   emit function; the tier names only record what the analysis found.

   Text-separator protocol ([render_to_string] parity, required for
   hydration): adjacent text nodes must be delimited by [<!-- -->] when
   [separators] is true. The walk threads a compile-time textness state:
   when both sides of a boundary are known, the separator is emitted behind
   a plain [if separators] check (or not at all); when the left side is a
   [Dynamic_element] hole the generated code threads a [prev_text] ref,
   assigned from [React_dom.write_element_to_buffer]'s result. The ref is
   only read while the compile-time state is [Ct_unknown], so static parts
   and string holes never need to update it. *)
let emit_parts_emit_fn ~loc parts =
  let open Static_analysis in
  (* Emit one [Dynamic_attr_slot] hole. For optional slots we peek through
     an obvious [Some e]/[None] to skip the runtime [match]; common when a
     caller writes [?foo=Some x] or [?foo=None] literally. *)
  let write_attr_slot ~info ~expr ~is_optional =
    let loc = expr.pexp_loc in
    if not is_optional then emit_attr_value_write ~loc ~info ~value_expr:expr
    else
      match expr.pexp_desc with
      | Pexp_construct ({ txt = Lident "None"; _ }, None) -> [%expr ()]
      | Pexp_construct ({ txt = Lident "Some"; _ }, Some inner) -> emit_attr_value_write ~loc ~info ~value_expr:inner
      | _ ->
          let write_some = emit_attr_value_write ~loc ~info ~value_expr:[%expr v] in
          let value_ty = attr_value_core_type ~loc info.kind in
          [%expr match ([%e expr] : [%t value_ty] option) with None -> () | Some v -> [%e write_some]]
  in
  (* [Dynamic_attr_slot] lives inside the open tag: it doesn't touch the
     child text run. *)
  let after_part state = function
    | Static_str { ends_text; _ } -> if ends_text then Ct_text else Ct_markup
    | Dynamic_string _ | Dynamic_int _ -> Ct_text
    | Dynamic_element _ -> Ct_unknown
    | Dynamic_attr_slot _ -> state
  in
  let begins_with_text = function
    | Static_str { starts_text; _ } -> starts_text
    | Dynamic_string _ | Dynamic_int _ -> true
    | Dynamic_element _ | Dynamic_attr_slot _ -> false
  in
  (* Prepass: the [prev_text] ref is read when a text-beginning part or a
     [Dynamic_element] hole runs while the compile-time state is
     [Ct_unknown]. When that never happens, skip declaring the ref. *)
  let prev_text_ref_needed =
    let rec loop state = function
      | [] -> false
      | part :: rest ->
          let reads_ref =
            match part with Dynamic_element _ -> state = Ct_unknown | _ -> begins_with_text part && state = Ct_unknown
          in
          reads_ref || loop (after_part state part) rest
    in
    loop Ct_markup parts
  in
  let separator ~state =
    match state with
    | Ct_markup -> None
    | Ct_text -> Some [%expr if __separators then Buffer.add_string __buf "<!-- -->"]
    | Ct_unknown -> Some [%expr if !__prev_text && __separators then Buffer.add_string __buf "<!-- -->"]
  in
  let uses_separators = ref false in
  let writes =
    let rec loop state = function
      | [] -> []
      | part :: rest ->
          let maybe_separator =
            if begins_with_text part then (
              let sep = separator ~state in
              if Option.is_some sep then uses_separators := true;
              sep)
            else None
          in
          let write =
            match part with
            | Static_str { html; _ } when String.length html = 0 ->
                (* Nothing to write: an empty text chunk only participates
                   in the text-run tracking (compile-time state). *)
                None
            | Static_str { html; _ } -> Some [%expr Buffer.add_string __buf [%e estring ~loc html]]
            | Dynamic_string e ->
                let loc = e.pexp_loc in
                Some [%expr React_dom.escape_to_buffer __buf [%e e]]
            | Dynamic_int e ->
                let loc = e.pexp_loc in
                Some [%expr Buffer.add_string __buf (Stdlib.string_of_int [%e e])]
            | Dynamic_element e ->
                let loc = e.pexp_loc in
                uses_separators := true;
                let prev_text_arg =
                  match state with
                  | Ct_text -> [%expr true]
                  | Ct_markup -> [%expr false]
                  | Ct_unknown -> [%expr !__prev_text]
                in
                if prev_text_ref_needed then
                  Some
                    [%expr
                      __prev_text :=
                        React_dom.write_element_to_buffer __buf ~separators:__separators ~prev_text:[%e prev_text_arg]
                          [%e e]]
                else
                  Some
                    [%expr
                      let (_ : bool) =
                        React_dom.write_element_to_buffer __buf ~separators:__separators ~prev_text:[%e prev_text_arg]
                          [%e e]
                      in
                      ()]
            | Dynamic_attr_slot { info; expr; is_optional } -> Some (write_attr_slot ~info ~expr ~is_optional)
          in
          let stmts = List.filter_map ~f:(fun x -> x) [ maybe_separator; write ] in
          stmts @ loop (after_part state part) rest
    in
    loop Ct_markup parts
  in
  let body =
    List.fold_right writes ~init:[%expr ()] ~f:(fun w acc ->
        [%expr
          [%e w];
          [%e acc]])
  in
  let body =
    if prev_text_ref_needed then
      [%expr
        let __prev_text = ref false in
        [%e body]]
    else body
  in
  if !uses_separators then [%expr fun __buf ~separators:__separators -> [%e body]]
  else [%expr fun __buf ~separators:_ -> [%e body]]

let rewrite_lowercase ~loc tag_name args children =
  let key =
    args |> List.find_opt ~f:(fun (label, _) -> get_label label = "key") |> Option.map (fun (_, value) -> value)
  in
  let props = transform_lowercase_props ~loc ~tag_name args in
  match Static_analysis.analyze_element ~tag_name ~attrs:args ~children with
  | Static_analysis.Fully_static html ->
      let html_with_doctype = Static_analysis.maybe_add_doctype tag_name html in
      let html_expr = estring ~loc html_with_doctype in
      let original = generate_create_element ~loc ~tag_name ~key ~props ~children in
      [%expr React.Static { prerendered = [%e html_expr]; original = [%e original] }]
  | Static_analysis.Needs_string_concat parts | Static_analysis.Needs_buffer parts ->
      (* Emit a [Buffer.t -> separators:bool -> unit] that writes directly into the caller's
         buffer. Avoids the N-per-subtree [Buffer.create] + [Buffer.contents]
         that a [Static] wrapping would cost.

         [original] is a thunk that rebuilds the variant-tree on demand for
         [clone_element] ; zero-alloc unless called. *)
      let parts_with_doctype =
        match tag_name with "html" -> Static_analysis.static_markup "<!DOCTYPE html>" :: parts | _ -> parts
      in
      let emit_fn = emit_parts_emit_fn ~loc parts_with_doctype in
      let original_tree = generate_create_element ~loc ~tag_name ~key ~props ~children in
      let original_thunk = [%expr fun () -> [%e original_tree]] in
      [%expr React.Writer { emit = [%e emit_fn]; original = [%e original_thunk] }]
  | Static_analysis.Cannot_optimize -> generate_create_element ~loc ~tag_name ~key ~props ~children

let split_args args =
  let children = ref (Location.none, []) in
  let rest =
    List.filter_map args ~f:(function
      | Labelled "children", children_expression ->
          let children' = unwrap_children [] children_expression in
          children := (children_expression.pexp_loc, children');
          None
      | arg_label, e -> Some (arg_label, e))
  in
  let children_prop = match !children with _loc, [] -> None | _loc, children -> Some children in
  (children_prop, rest)

let reverse_pexp_list ~loc expr =
  let rec go acc = function
    | [%expr []] -> acc
    | [%expr [%e? hd] :: [%e? tl]] -> go [%expr [%e hd] :: [%e acc]] tl
    | expr -> expr
  in
  go [%expr []] expr

let list_have_tail expr =
  match expr with
  | Pexp_construct ({ txt = Lident "::"; _ }, Some { pexp_desc = Pexp_tuple _; _ })
  | Pexp_construct ({ txt = Lident "[]"; _ }, None) ->
      false
  | _ -> true

let transform_items_of_list ~loc children =
  let rec run_mapper children accum =
    match children with
    | [%expr []] -> reverse_pexp_list ~loc accum
    | [%expr [%e? v] :: [%e? acc]] when list_have_tail acc.pexp_desc -> [%expr [%e v]]
    | [%expr [%e? v] :: [%e? acc]] -> run_mapper acc [%expr [%e v] :: [%e accum]]
    | notAList -> notAList
  in
  run_mapper children [%expr []]

let remove_warning_16_optional_argument_cannot_be_erased ~loc =
  let open Ast_helper in
  {
    attr_name = { txt = "warning"; loc };
    attr_payload = PStr [ Str.eval (Exp.constant (Const.string "-16")) ];
    attr_loc = loc;
  }

(* Finds the name of the variable the binding is assigned to, otherwise raises *)
let get_function_name binding =
  match binding with
  | { pvb_pat = { ppat_desc = Ppat_var { txt } } } -> txt
  | _ -> raise_errorf ~loc:binding.pvb_loc "react.component calls cannot be destructured."

(* TODO: there are a few unsupported features inside of blocks - Pexp_letmodule , Pexp_letexception , Pexp_ifthenelse *)
let add_unit_at_the_last_argument expression =
  let loc = expression.pexp_loc in
  let has_final_unit params =
    match List.rev params with
    | {
        pparam_desc = Pparam_val (Nolabel, _, { ppat_desc = Ppat_construct ({ txt = Lident "()" }, _) | Ppat_any; _ });
        _;
      }
      :: _ ->
        true
    | _ -> false
  in
  let unit_param = { pparam_loc = loc; pparam_desc = Pparam_val (Nolabel, None, [%pat? ()]) } in
  let rec find_innermost_function_and_add_unit expression =
    match expression.pexp_desc with
    | Pexp_function (params, constraint_, Pfunction_body inner_body) -> (
        match inner_body.pexp_desc with
        | Pexp_function _ ->
            let modified_inner = find_innermost_function_and_add_unit inner_body in
            { expression with pexp_desc = Pexp_function (params, constraint_, Pfunction_body modified_inner) }
        | _ when (not (has_final_unit params)) && params <> [] ->
            {
              expression with
              pexp_attributes = remove_warning_16_optional_argument_cannot_be_erased ~loc :: expression.pexp_attributes;
              pexp_desc = Pexp_function (params @ [ unit_param ], constraint_, Pfunction_body inner_body);
            }
        | _ -> expression)
    | Pexp_function _ -> expression
    | _ -> expression
  in
  let rec inner expression =
    match expression.pexp_desc with
    | Pexp_function _ -> find_innermost_function_and_add_unit expression
    (* let make = {let foo = bar in (~prop) => ...} *)
    | Pexp_let (recursive, vbs, internal_expression) ->
        pexp_let ~loc:expression.pexp_loc recursive vbs (inner internal_expression)
    (* let make = React.forward_ref((~prop) => ...) *)
    | Pexp_apply (_, [ (Nolabel, internal_expression) ]) -> inner internal_expression
    (* let make = React.memo_custom_compare_props((~prop) => ..., (prevPros, nextProps) => true) *)
    | Pexp_apply
        (_, [ (Nolabel, internal_expression); ((Nolabel, { pexp_desc = Pexp_function _; _ }) as _compare_props) ]) ->
        inner internal_expression
    | Pexp_sequence (wrapper_expression, internal_expression) ->
        pexp_sequence ~loc:expression.pexp_loc wrapper_expression (inner internal_expression)
    | _ -> expression
  in
  inner expression

let transform_fun_body_expression expr fn =
  let rec find_innermost_body_and_transform expr =
    match expr.pexp_desc with
    | Pexp_function (params, constraint_, Pfunction_body inner_body) -> (
        match inner_body.pexp_desc with
        | Pexp_function _ ->
            let transformed_inner = find_innermost_body_and_transform inner_body in
            { expr with pexp_desc = Pexp_function (params, constraint_, Pfunction_body transformed_inner) }
        | _ ->
            let transformed_body = fn inner_body in
            { expr with pexp_desc = Pexp_function (params, constraint_, Pfunction_body transformed_body) })
    | _ -> fn expr
  in
  find_innermost_body_and_transform expr

let get_label_or_empty = function Labelled str | Optional str -> str | Nolabel -> ""

let safe_type_from_label = function
  | (Labelled name | Optional name) when String.length name > 0 && name.[0] = '_' -> "T" ^ name
  | Labelled name | Optional name -> name
  | Nolabel -> "T"

type object_field = { method_name : string; value_expr : expression }

type component_arg = {
  public_label : arg_label;
  internal_label : arg_label;
  default_value : expression option;
  loc : Location.t;
  core_type : core_type option;
}

let build_object_expression ~as_type ~loc fields =
  let methods =
    List.map fields ~f:(fun { method_name; value_expr } ->
        pcf_method ~loc (Located.mk method_name ~loc, Public, Cfk_concrete (Fresh, value_expr)))
  in
  pexp_constraint ~loc (pexp_object ~loc (class_structure ~self:(ppat_any ~loc) ~fields:methods)) as_type

let option_type ~loc inner = ptyp_constr ~loc { txt = Lident "option"; loc } [ inner ]

let strip_option_type core_type =
  match core_type.ptyp_desc with
  | Ptyp_constr (({ txt = Lident "option"; _ } | { txt = Ldot (Lident "*predef*", "option"); _ }), [ inner ]) ->
      Some inner
  | _ -> None

let component_arg_public_name arg = get_label_or_empty arg.public_label

let component_arg_type_var arg =
  let loc = arg.loc in
  ptyp_var ~loc (safe_type_from_label arg.public_label)

let component_arg_public_arg_type ~from_signature arg =
  match (arg.public_label, arg.core_type, arg.default_value) with
  | Optional _, Some core_type, _ when not from_signature -> (
      match strip_option_type core_type with Some inner -> inner | None -> core_type)
  | Optional _, Some core_type, _ -> core_type
  | _, Some core_type, Some _ -> core_type
  | Labelled _, Some core_type, _ -> core_type
  | (Labelled _ | Optional _), None, _ -> component_arg_type_var arg
  | Nolabel, _, _ -> assert false

let component_arg_field_type arg =
  match (arg.public_label, arg.core_type, arg.default_value) with
  | Optional _, Some core_type, _ -> (
      match strip_option_type core_type with
      | Some inner -> option_type ~loc:arg.loc inner
      | None -> option_type ~loc:arg.loc core_type)
  | _, Some core_type, Some _ -> option_type ~loc:arg.loc core_type
  | Labelled _, Some core_type, _ -> core_type
  | Optional _, None, _ -> option_type ~loc:arg.loc (component_arg_type_var arg)
  | Labelled _, None, _ -> component_arg_type_var arg
  | Nolabel, _, _ -> assert false

let make_props_name fn_name = fn_name ^ "_props"

let make_object_field ~loc (name, core_type) =
  { pof_desc = Otag ({ loc; txt = name }, core_type); pof_loc = loc; pof_attributes = [] }

let make_props_type ~loc args =
  let object_fields = List.map args ~f:(fun arg -> (component_arg_public_name arg, component_arg_field_type arg)) in
  {
    ptyp_desc = Ptyp_object (List.map object_fields ~f:(make_object_field ~loc), Closed);
    ptyp_loc = loc;
    ptyp_loc_stack = [];
    ptyp_attributes = [];
  }

let react_component_like_type ~loc props_type return_type =
  ptyp_constr ~loc { txt = Ldot (Lident "React", "component_like"); loc } [ props_type; return_type ]

let is_unit_or_any_pattern pattern =
  match pattern.ppat_desc with Ppat_construct ({ txt = Lident "()"; _ }, None) | Ppat_any -> true | _ -> false

let pattern_core_type pattern =
  match pattern.ppat_desc with Ppat_constraint (_, core_type) -> Some core_type | _ -> None

let rec unwrap_component_expression expr =
  match expr.pexp_desc with
  | Pexp_constraint (expr, _) -> unwrap_component_expression expr
  | Pexp_let (_, _, inner) -> unwrap_component_expression inner
  | Pexp_apply (_, [ (Nolabel, inner) ]) -> unwrap_component_expression inner
  | Pexp_apply (_, [ (Nolabel, inner); (Nolabel, { pexp_desc = Pexp_function _; _ }) ]) ->
      unwrap_component_expression inner
  | Pexp_sequence (_, inner) -> unwrap_component_expression inner
  | _ -> expr

let rec collect_component_fun_params acc expr =
  match expr.pexp_desc with
  | Pexp_constraint (expr, _) -> collect_component_fun_params acc expr
  | Pexp_function (params, _, Pfunction_body body) -> (
      match body.pexp_desc with
      | Pexp_function _ -> collect_component_fun_params (acc @ params) body
      | _ -> acc @ params)
  | _ -> acc

let extract_component_args expr =
  let params = collect_component_fun_params [] (unwrap_component_expression expr) in
  let last_index = List.length params - 1 in
  params
  |> List.mapi ~f:(fun index param ->
      match param.pparam_desc with
      | Pparam_newtype _ -> None
      | Pparam_val (Nolabel, _, pattern) when index = last_index && is_unit_or_any_pattern pattern -> None
      | Pparam_val ((Labelled "key" | Optional "key"), _, pattern) ->
          raise_errorf ~loc:pattern.ppat_loc
            "~key cannot be accessed from the component props. Please set the key where the component is being used."
      | Pparam_val (((Labelled _ | Optional _) as arg_label), default_value, pattern) ->
          Some
            {
              public_label = arg_label;
              internal_label = arg_label;
              default_value;
              loc = pattern.ppat_loc;
              core_type = pattern_core_type pattern;
            }
      | Pparam_val (Nolabel, _, pattern) ->
          raise_errorf ~loc:pattern.ppat_loc
            "props need to be labelled arguments. If your component doesn't have any props, use () or _ instead of a \
             name.")
  |> List.filter_map ~f:Fun.id

let build_make_props_binding ~loc ~fn_name args =
  let props_type = make_props_type ~loc args in
  let object_fields =
    List.map args ~f:(fun arg ->
        let field_name = component_arg_public_name arg in
        let value_expr = evar ~loc:arg.loc field_name in
        { method_name = field_name; value_expr })
  in
  let body = build_object_expression ~as_type:props_type ~loc object_fields in
  let body = pexp_fun ~loc Nolabel None [%pat? ()] body in
  let body =
    List.fold_right args ~init:body ~f:(fun arg acc ->
        let arg_name = component_arg_public_name arg in
        let pattern =
          ppat_constraint ~loc:arg.loc
            (ppat_var ~loc:arg.loc { txt = arg_name; loc = arg.loc })
            (component_arg_field_type arg)
        in
        pexp_fun ~loc:arg.loc arg.public_label None pattern acc)
  in
  value_binding ~loc ~pat:(ppat_var ~loc { txt = make_props_name fn_name; loc }) ~expr:body

let build_public_component_binding ~loc ~fn_name args =
  let props_type = make_props_type ~loc args in
  let has_props = args <> [] in
  let props_name = if has_props then "Props" else "_Props" in
  let props_expr = evar ~loc (if has_props then "Props" else "_Props") in
  let key_arg = (Optional "key", evar ~loc "key") in
  let prop_args =
    List.map args ~f:(fun arg ->
        let value_expr = pexp_send ~loc props_expr { txt = component_arg_public_name arg; loc = arg.loc } in
        (arg.internal_label, value_expr))
  in
  let call_expr = pexp_apply ~loc (ident ~loc fn_name) ((key_arg :: prop_args) @ [ (Nolabel, [%expr ()]) ]) in
  let props_pattern = ppat_constraint ~loc (ppat_var ~loc { txt = props_name; loc }) props_type in
  let body = pexp_fun ~loc Nolabel None props_pattern call_expr in
  let key_pattern = ppat_constraint ~loc (ppat_var ~loc { txt = "key"; loc }) [%type: string option] in
  let body = pexp_fun ~loc (Optional "key") None key_pattern body in
  value_binding ~loc ~pat:(ppat_var ~loc { txt = fn_name; loc }) ~expr:body

let build_make_props_signature_item ~loc ~fn_name args =
  let props_type = make_props_type ~loc args in
  let make_props_type =
    List.fold_right args
      ~init:(ptyp_arrow ~loc Nolabel [%type: unit] props_type)
      ~f:(fun arg acc ->
        ptyp_arrow ~loc:arg.loc arg.public_label (component_arg_public_arg_type ~from_signature:true arg) acc)
  in
  psig_value ~loc
    {
      pval_name = { txt = make_props_name fn_name; loc };
      pval_type = make_props_type;
      pval_prim = [];
      pval_attributes = [];
      pval_loc = loc;
    }

let build_public_component_signature_item ~loc ~fn_name ~attributes args return_type =
  let props_type = make_props_type ~loc args in
  let make_type = react_component_like_type ~loc props_type return_type in
  psig_value ~loc
    {
      pval_name = { txt = fn_name; loc };
      pval_type = make_type;
      pval_prim = [];
      pval_attributes = attributes;
      pval_loc = loc;
    }

let extract_component_signature_args pval_type =
  let rec go args core_type =
    match core_type.ptyp_desc with
    | Ptyp_arrow (Nolabel, { ptyp_desc = Ptyp_constr ({ txt = Lident "unit"; _ }, []); _ }, rest) -> go args rest
    | Ptyp_arrow (((Labelled _ | Optional _) as arg_label), core_type, rest) ->
        go
          (args
          @ [
              {
                public_label = arg_label;
                internal_label = arg_label;
                default_value = None;
                loc = core_type.ptyp_loc;
                core_type = Some core_type;
              };
            ])
          rest
    | Ptyp_arrow (Nolabel, _, rest) -> go args rest
    | _ -> (args, core_type)
  in
  go [] pval_type

let expand_make_binding binding react_element_variant_wrapping =
  let attributers = binding.pvb_attributes |> List.filter ~f:non_react_attributes in
  let loc = binding.pvb_loc in
  let ghost_loc = { binding.pvb_loc with loc_ghost = true } in
  let binding_with_unit = add_unit_at_the_last_argument binding.pvb_expr in
  let binding_expr = transform_fun_body_expression binding_with_unit react_element_variant_wrapping in
  let name = ppat_var ~loc:ghost_loc { txt = get_function_name binding; loc = ghost_loc } in
  let key_arg = Optional "key" in
  let default_value = None in
  let underscore = ppat_var ~loc:ghost_loc { txt = "_"; loc } in
  let core_type = [%type: string option] in
  let key_pattern = ppat_constraint ~loc underscore core_type in
  (* Append key argument since we want to allow users of this component to set key (and assign it to _ since it shouldn't be used) *)
  let function_body = pexp_fun ~loc:ghost_loc key_arg default_value key_pattern binding_expr in
  (* Since expand_make_binding is called on both native and js contexts, we need to keep the attributes *)
  { (value_binding ~loc:ghost_loc ~pat:name ~expr:function_body) with pvb_attributes = attributers }

let rewrite_signature_item signature_item =
  match signature_item with
  | { psig_loc = loc; psig_desc = Psig_value { pval_name = { txt = fn_name; _ }; pval_attributes; pval_type } } -> (
      match List.filter ~f:has_any_react_component_attribute pval_attributes with
      | [] -> signature_item
      | [ _ ] ->
          let args, return_type = extract_component_signature_args pval_type in
          let make_props_sig = build_make_props_signature_item ~loc ~fn_name args in
          let make_sig =
            build_public_component_signature_item ~loc ~fn_name
              ~attributes:(List.filter ~f:non_react_attributes pval_attributes)
              args return_type
          in
          [%sigi:
            include sig
              [%%i make_props_sig]
              [%%i make_sig]
            end]
      | _ ->
          [%sigi:
            [%%ocaml.error "server-reason-react: there's seems to be an error in the signature of the component."]])
  | _ -> signature_item

let rewrite_structure_item structure_item =
  match structure_item.pstr_desc with
  (* external *)
  | Pstr_primitive ({ pval_name = { txt = _fn_name }; pval_attributes; pval_type = _ } as _value_description) -> (
      match List.filter ~f:(fun attr -> has_attr attr react_dot_component) pval_attributes with
      | [] -> structure_item
      | _ ->
          let loc = structure_item.pstr_loc in
          [%stri
            [%%ocaml.error
            "externals aren't supported on server-reason-react. externals are used to bind to React components defined \
             in JavaScript, in the server, that doesn't make sense. If you need to render this on the server, \
             implement a placeholder or an empty element"]])
  | Pstr_value (rec_flag, value_bindings) -> (
      try
        let rewrite_component_binding vb =
          if is_react_component_binding vb then
            let loc = vb.pvb_loc in
            let fn_name = get_function_name vb in
            let args = extract_component_args vb.pvb_expr in
            let internal_binding =
              expand_make_binding vb (fun expr ->
                  let loc = expr.pexp_loc in
                  [%expr React.Upper_case_component (Stdlib.__FUNCTION__, fun () -> [%e expr])])
            in
            Some
              ( internal_binding,
                build_make_props_binding ~loc ~fn_name args,
                build_public_component_binding ~loc ~fn_name args )
          else None
        in
        let rewrites = List.map value_bindings ~f:rewrite_component_binding in
        let make_props_bindings =
          List.filter_map rewrites ~f:(function
            | Some (_, make_props_binding, _) -> Some make_props_binding
            | None -> None)
        in
        let public_bindings =
          List.filter_map rewrites ~f:(function Some (_, _, public_binding) -> Some public_binding | None -> None)
        in
        let internal_bindings =
          List.map2 value_bindings rewrites ~f:(fun vb rewrite ->
              match rewrite with Some (internal_binding, _, _) -> internal_binding | None -> vb)
        in
        match make_props_bindings with
        | [] -> pstr_value ~loc:structure_item.pstr_loc rec_flag internal_bindings
        | _ -> (
            let loc = structure_item.pstr_loc in
            let is_react_attr attr =
              let name = attr.attr_name.txt in
              String.length name >= 6 && String.sub name 0 6 = "react."
            in
            let propagated_attrs =
              List.concat_map value_bindings ~f:(fun vb ->
                  List.filter vb.pvb_attributes ~f:(fun attr -> not (is_react_attr attr)))
            in
            let include_stri =
              [%stri
                include struct
                  [%%i pstr_value ~loc:structure_item.pstr_loc Nonrecursive make_props_bindings]
                  [%%i pstr_value ~loc:structure_item.pstr_loc rec_flag internal_bindings]
                  [%%i pstr_value ~loc:structure_item.pstr_loc Nonrecursive public_bindings]
                end]
            in
            match (propagated_attrs, include_stri.pstr_desc) with
            | _ :: _, Pstr_include incl ->
                { include_stri with pstr_desc = Pstr_include { incl with pincl_attributes = propagated_attrs } }
            | _ -> include_stri)
      with Error err -> pstr_eval ~loc:structure_item.pstr_loc err [])
  | _ -> structure_item

let validate_tag_children tag children attributes : (unit, string) result =
  match Html.is_self_closing_tag tag with
  | true when Option.fold ~none:false ~some:(fun children -> List.length children > 0) children ->
      Error (Printf.sprintf {|"%s" is a self-closing tag and must not have "children".\n|} tag)
  | true
    when List.exists
           ~f:(fun (arg_label, _) ->
             match arg_label with
             | Labelled "dangerously_set_inner_html" | Optional "dangerously_set_inner_html" -> true
             | _ -> false)
           attributes ->
      Error (Printf.sprintf {|server-reason-react: "%s" is a self-closing tag and must not have "children".\n|} tag)
  | false -> Ok ()
  | true -> Ok ()

let traverse =
  object (_)
    inherit [Expansion_context.Base.t] Ast_traverse.map_with_context as super
    method! structure_item ctx structure_item = rewrite_structure_item (super#structure_item ctx structure_item)
    method! signature_item ctx signature_item = rewrite_signature_item (super#signature_item ctx signature_item)

    method! expression ctx expr =
      let expr = super#expression ctx expr in
      (* Rewrite React_dom.Style.make(~k:v, ..., ()) to a direct list literal at
         compile time. On stock OCaml the 347-optional-arg signature forces
         ~1460 words/call; the PPX elides this entirely when all args are
         labeled string values. Falls through if optional args or unknown
         names appear. *)
      let expr = Style_rewrite.rewrite_expression expr in
      try
        match expr.pexp_desc with
        | Pexp_apply (({ pexp_desc = Pexp_ident _; pexp_loc = loc; _ } as tag), args)
          when has_jsx_attr expr.pexp_attributes -> (
            let children, rest_of_args = split_args args in
            match validate_tag_children (Pprintast.string_of_expression tag) children rest_of_args with
            | Error err -> [%expr [%ocaml.error [%e estring ~loc:expr.pexp_loc err]]]
            | Ok () -> (
                match tag.pexp_desc with
                (* div() [@Jsx] *)
                | Pexp_ident { txt = Lident name; loc = _name_loc } ->
                    rewrite_lowercase ~loc:expr.pexp_loc name rest_of_args children
                (* Reason adds `create_element` as default when an uppercase is found,
                   we change it back to make *)
                (* Foo.create_element() [@Jsx] *)
                | Pexp_ident { txt = Ldot (module_path, ("createElement" | "make")); loc } ->
                    let id = { loc; txt = Ldot (module_path, "make") } in
                    rewrite_component ~loc:expr.pexp_loc id rest_of_args children
                (* local_function() [@Jsx] *)
                | Pexp_ident id -> rewrite_component ~loc:expr.pexp_loc id rest_of_args children
                | _ -> assert false))
        (* div() [@Jsx] *)
        | Pexp_apply (tag, _props) when has_jsx_attr expr.pexp_attributes ->
            raise_errorf ~loc:expr.pexp_loc "jsx: %s should be an identifier, not an expression"
              (Pprintast.string_of_expression tag)
        (* <> </> is represented as a list in the Parsetree with [@Jsx] *)
        | Pexp_construct ({ txt = Lident "::"; loc }, Some { pexp_desc = Pexp_tuple _; _ })
        | Pexp_construct ({ txt = Lident "[]"; loc }, None) -> (
            let jsx_attr, rest_attributes = List.partition ~f:is_jsx expr.pexp_attributes in
            match (jsx_attr, rest_attributes) with
            | [], _ -> expr
            | _, rest_attributes ->
                let children = transform_items_of_list ~loc expr in
                let new_expr = [%expr React.fragment (React.list [%e children])] in
                { new_expr with pexp_attributes = rest_attributes })
        | _ -> expr
      with Error err -> [%expr [%e err]]
  end

let () =
  Ppxlib.Driver.V2.register_transformation "server-reason-react.ppx" ~preprocess_impl:traverse#structure
    ~preprocess_intf:traverse#signature
