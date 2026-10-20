type 'value ref = { mutable current : 'value }
type dom_element
type dom_ref = Callback_dom_ref of (dom_element option -> unit) | Current_dom_ref of dom_element option ref

module Ref = struct
  type t = dom_ref
  type current_dom_ref = dom_element option ref
  type callback_dom_ref = dom_element option -> unit

  let dom_ref (v : current_dom_ref) = Current_dom_ref v
  let callback_dom_ref (v : callback_dom_ref) = Callback_dom_ref v
end

let create_ref () = { current = None }
let use_ref value = { current = value }
let forward_ref f = f ()

exception Impossible_in_ssr of string

let fail_impossible_action_in_ssr fn =
  raise (Impossible_in_ssr (Printf.sprintf {|'%s' shouldn't run on the server|} fn))

module Event = struct
  type 'a synthetic

  type target_like =
    < checked : bool
    ; class_name : string
    ; id : string
    ; inner_html : string
    ; name : string
    ; tag_name : string
    ; text_content : string
    ; value : string >

  let fail name = fail_impossible_action_in_ssr ("React.Event." ^ name)

  module Make_event_with_type (Type : sig
    type t
  end) =
  struct
    let bubbles : Type.t -> bool = fun _ -> fail "bubbles"
    let cancelable : Type.t -> bool = fun _ -> fail "cancelable"
    let current_target : Type.t -> target_like = fun _ -> fail "current_target"
    let default_prevented : Type.t -> bool = fun _ -> fail "default_prevented"
    let event_phase : Type.t -> int = fun _ -> fail "event_phase"
    let is_trusted : Type.t -> bool = fun _ -> fail "is_trusted"
    let native_event : Type.t -> target_like = fun _ -> fail "native_event"
    let prevent_default : Type.t -> unit = fun _ -> fail "prevent_default"
    let is_default_prevented : Type.t -> bool = fun _ -> fail "is_default_prevented"
    let stop_propagation : Type.t -> unit = fun _ -> fail "stop_propagation"
    let is_propagation_stopped : Type.t -> bool = fun _ -> fail "is_propagation_stopped"
    let target : Type.t -> target_like = fun _ -> fail "target"
    let time_stamp : Type.t -> float = fun _ -> fail "time_stamp"
    let type_ : Type.t -> string = fun _ -> fail "type_"
    let persist : Type.t -> unit = fun _ -> fail "persist"
  end

  module Synthetic = struct
    type tag
    type t = tag synthetic

    let bubbles : 'a synthetic -> bool = fun _ -> fail "Synthetic.bubbles"
    let cancelable : 'a synthetic -> bool = fun _ -> fail "Synthetic.cancelable"
    let current_target : 'a synthetic -> target_like = fun _ -> fail "Synthetic.current_target"
    let default_prevented : 'a synthetic -> bool = fun _ -> fail "Synthetic.default_prevented"
    let event_phase : 'a synthetic -> int = fun _ -> fail "Synthetic.event_phase"
    let is_trusted : 'a synthetic -> bool = fun _ -> fail "Synthetic.is_trusted"
    let native_event : 'a synthetic -> target_like = fun _ -> fail "Synthetic.native_event"
    let prevent_default : 'a synthetic -> unit = fun _ -> fail "Synthetic.prevent_default"
    let is_default_prevented : 'a synthetic -> bool = fun _ -> fail "Synthetic.is_default_prevented"
    let stop_propagation : 'a synthetic -> unit = fun _ -> fail "Synthetic.stop_propagation"
    let is_propagation_stopped : 'a synthetic -> bool = fun _ -> fail "Synthetic.is_propagation_stopped"
    let target : 'a synthetic -> target_like = fun _ -> fail "Synthetic.target"
    let time_stamp : 'a synthetic -> float = fun _ -> fail "Synthetic.time_stamp"
    let type_ : 'a synthetic -> string = fun _ -> fail "Synthetic.type_"
    let persist : 'a synthetic -> unit = fun _ -> fail "Synthetic.persist"
  end

  (* let to_synthetic_event : 'a synthetic -> Synthetic.t = i -> i *)

  module Clipboard = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)

    let clipboard_data : t -> target_like = fun _ -> fail "Clipboard.clipboard_data"
  end

  module Composition = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)

    let data : t -> string = fun _ -> fail "Composition.data"
  end

  module Keyboard = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)

    let alt_key : t -> bool = fun _ -> fail "Keyboard.alt_key"
    let char_code : t -> int = fun _ -> fail "Keyboard.char_code"
    let ctrl_key : t -> bool = fun _ -> fail "Keyboard.ctrl_key"
    let get_modifier_state : t -> string -> bool = fun _ _ -> fail "Keyboard.get_modifier_state"
    let key : t -> string = fun _ -> fail "Keyboard.key"
    let key_code : t -> int = fun _ -> fail "Keyboard.key_code"
    let locale : t -> string = fun _ -> fail "Keyboard.locale"
    let location : t -> int = fun _ -> fail "Keyboard.location"
    let meta_key : t -> bool = fun _ -> fail "Keyboard.meta_key"
    let repeat : t -> bool = fun _ -> fail "Keyboard.repeat"
    let shift_key : t -> bool = fun _ -> fail "Keyboard.shift_key"
    let which : t -> int = fun _ -> fail "Keyboard.which"
  end

  module Focus = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)

    let related_target : t -> target_like option = fun _ -> fail "Focus.related_target"
  end

  module Form = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)
  end

  module Mouse = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)

    let alt_key : t -> bool = fun _ -> fail "Mouse.alt_key"
    let button : t -> int = fun _ -> fail "Mouse.button"
    let buttons : t -> int = fun _ -> fail "Mouse.buttons"
    let client_x : t -> int = fun _ -> fail "Mouse.client_x"
    let client_y : t -> int = fun _ -> fail "Mouse.client_y"
    let ctrl_key : t -> bool = fun _ -> fail "Mouse.ctrl_key"
    let get_modifier_state : t -> string -> bool = fun _ _ -> fail "Mouse.get_modifier_state"
    let meta_key : t -> bool = fun _ -> fail "Mouse.meta_key"
    let movement_x : t -> int = fun _ -> fail "Mouse.movement_x"
    let movement_y : t -> int = fun _ -> fail "Mouse.movement_y"
    let page_x : t -> int = fun _ -> fail "Mouse.page_x"
    let page_y : t -> int = fun _ -> fail "Mouse.page_y"
    let related_target : t -> target_like option = fun _ -> fail "Mouse.related_target"
    let screen_x : t -> int = fun _ -> fail "Mouse.screen_x"
    let screen_y : t -> int = fun _ -> fail "Mouse.screen_y"
    let shift_key : t -> bool = fun _ -> fail "Mouse.shift_key"
  end

  module Pointer = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)

    let detail : t -> int = fun _ -> fail "Pointer.detail"

    (* let view : t -> Dom.window *)
    let screen_x : t -> int = fun _ -> fail "Pointer.screen_x"
    let screen_y : t -> int = fun _ -> fail "Pointer.screen_y"
    let client_x : t -> int = fun _ -> fail "Pointer.client_x"
    let client_y : t -> int = fun _ -> fail "Pointer.client_y"
    let page_x : t -> int = fun _ -> fail "Pointer.page_x"
    let page_y : t -> int = fun _ -> fail "Pointer.page_y"
    let movement_x : t -> int = fun _ -> fail "Pointer.movement_x"
    let movement_y : t -> int = fun _ -> fail "Pointer.movement_y"
    let ctrl_key : t -> bool = fun _ -> fail "Pointer.ctrl_key"
    let shift_key : t -> bool = fun _ -> fail "Pointer.shift_key"
    let alt_key : t -> bool = fun _ -> fail "Pointer.alt_key"
    let meta_key : t -> bool = fun _ -> fail "Pointer.meta_key"
    let get_modifier_state : t -> string -> bool = fun _ _ -> fail "Pointer.get_modifier_state"
    let button : t -> int = fun _ -> fail "Pointer.button"
    let buttons : t -> int = fun _ -> fail "Pointer.buttons"
    let related_target : t -> target_like option = fun _ -> fail "Pointer.related_target"

    (* let pointer_id : t -> Dom.event_pointer_id *)
    let width : t -> float = fun _ -> fail "Pointer.width"
    let height : t -> float = fun _ -> fail "Pointer.height"
    let pressure : t -> float = fun _ -> fail "Pointer.pressure"
    let tangential_pressure : t -> float = fun _ -> fail "Pointer.tangential_pressure"
    let tilt_x : t -> int = fun _ -> fail "Pointer.tilt_x"
    let tilt_y : t -> int = fun _ -> fail "Pointer.tilt_y"
    let twist : t -> int = fun _ -> fail "Pointer.twist"
    let pointer_type : t -> string = fun _ -> fail "Pointer.pointer_type"
    let is_primary : t -> bool = fun _ -> fail "Pointer.is_primary"
  end

  module Selection = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)
  end

  module Touch = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)

    let alt_key : t -> bool = fun _ -> fail "Touch.alt_key"
    let changed_touches : t -> target_like = fun _ -> fail "Touch.changed_touches"
    let ctrl_key : t -> bool = fun _ -> fail "Touch.ctrl_key"
    let get_modifier_state : t -> string -> bool = fun _ _ -> fail "Touch.get_modifier_state"
    let meta_key : t -> bool = fun _ -> fail "Touch.meta_key"
    let shift_key : t -> bool = fun _ -> fail "Touch.shift_key"
    let target_touches : t -> target_like = fun _ -> fail "Touch.target_touches"
    let touches : t -> target_like = fun _ -> fail "Touch.touches"
  end

  module Ui = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)

    let detail : t -> int = fun _ -> fail "Ui.detail"
    (* let view : t -> Dom.window *)
  end

  module Wheel = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)

    let delta_mode : t -> int = fun _ -> fail "Wheel.delta_mode"
    let delta_x : t -> float = fun _ -> fail "Wheel.delta_x"
    let delta_y : t -> float = fun _ -> fail "Wheel.delta_y"
    let delta_z : t -> float = fun _ -> fail "Wheel.delta_z"
  end

  module Media = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)
  end

  module Image = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)
  end

  module Animation = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)

    let animation_name : t -> string = fun _ -> fail "Animation.animation_name"
    let pseudo_element : t -> string = fun _ -> fail "Animation.pseudo_element"
    let elapsed_time : t -> float = fun _ -> fail "Animation.elapsed_time"
  end

  module Transition = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)

    let property_name : t -> string = fun _ -> fail "Transition.property_name"
    let pseudo_element : t -> string = fun _ -> fail "Transition.pseudo_element"
    let elapsed_time : t -> float = fun _ -> fail "Transition.elapsed_time"
  end

  module Drag = struct
    type tag
    type t = tag synthetic

    include Make_event_with_type (struct
      type nonrec t = t [@@nonrec]
    end)

    let alt_key : t -> bool = fun _ -> fail "Drag.alt_key"
    let button : t -> int = fun _ -> fail "Drag.button"
    let buttons : t -> int = fun _ -> fail "Drag.buttons"
    let client_x : t -> int = fun _ -> fail "Drag.client_x"
    let client_y : t -> int = fun _ -> fail "Drag.client_y"
    let ctrl_key : t -> bool = fun _ -> fail "Drag.ctrl_key"
    let get_modifier_state : t -> string -> bool = fun _ _ -> fail "Drag.get_modifier_state"
    let meta_key : t -> bool = fun _ -> fail "Drag.meta_key"
    let movement_x : t -> int = fun _ -> fail "Drag.movement_x"
    let movement_y : t -> int = fun _ -> fail "Drag.movement_y"
    let page_x : t -> int = fun _ -> fail "Drag.page_x"
    let page_y : t -> int = fun _ -> fail "Drag.page_y"
    let related_target : t -> target_like option = fun _ -> fail "Drag.related_target"
    let screen_x : t -> int = fun _ -> fail "Drag.screen_x"
    let screen_y : t -> int = fun _ -> fail "Drag.screen_y"
    let shift_key : t -> bool = fun _ -> fail "Drag.shift_key"
    let data_transfer : t -> target_like = fun _ -> fail "Drag.data_transfer"
  end
end

module Jsx = struct
  type event =
    | Drag of (Event.Drag.t -> unit)
    | Mouse of (Event.Mouse.t -> unit)
    | Selection of (Event.Selection.t -> unit)
    | Touch of (Event.Touch.t -> unit)
    | Ui of (Event.Ui.t -> unit)
    | Wheel of (Event.Wheel.t -> unit)
    | Clipboard of (Event.Clipboard.t -> unit)
    | Composition of (Event.Composition.t -> unit)
    | Transition of (Event.Transition.t -> unit)
    | Animation of (Event.Animation.t -> unit)
    | Pointer of (Event.Pointer.t -> unit)
    | Keyboard of (Event.Keyboard.t -> unit)
    | Focus of (Event.Focus.t -> unit)
    | Form of (Event.Form.t -> unit)
    | Media of (Event.Media.t -> unit)
    | Inline of string

  type prop =
    | Bool of (string * string * bool)
    | Booleanish_string of (string * string * bool)
    | String of (string * string * string)
    | Int of (string * string * int)
    | Float of (string * string * float)
    | Style of (string * string * string) list
    | Dangerously_inner_html of string
    | Ref of Ref.t
    | Event of string * event

  let bool name jsx_name value = Bool (name, jsx_name, value)
  let booleanish_string name jsx_name value = Booleanish_string (name, jsx_name, value)
  let string name jsx_name value = String (name, jsx_name, value)
  let style value = Style value
  let int name jsx_name value = Int (name, jsx_name, value)
  let float name jsx_name value = Float (name, jsx_name, value)
  let dangerously_inner_html value = Dangerously_inner_html value#__html
  let ref value = Ref value
  let event key value = Event (key, value)

  module Event = struct
    let drag key value = event key (Drag value)
    let mouse key value = event key (Mouse value)
    let selection key value = event key (Selection value)
    let touch key value = event key (Touch value)
    let ui key value = event key (Ui value)
    let wheel key value = event key (Wheel value)
    let clipboard key value = event key (Clipboard value)
    let composition key value = event key (Composition value)
    let transition key value = event key (Transition value)
    let animation key value = event key (Animation value)
    let pointer key value = event key (Pointer value)
    let keyboard key value = event key (Keyboard value)
    let focus key value = event key (Focus value)
    let form key value = event key (Form value)
    let media key value = event key (Media value)
  end
end

type ('props, 'return) component_like = ?key:string -> 'props -> 'return

and element =
  | Lower_case_element of lower_case_element
  | Upper_case_component of string * (unit -> element)
  | List of element list
  | Array of element array
  | Text of string
  | Int of int
  | Float of float
  | Static of { prerendered : string; original : element }
  | Writer of { emit : Buffer.t -> separators:bool -> unit; original : unit -> element }
      (** Like [Static] but writes directly into the caller's buffer. Used by the PPX for subtrees with static skeleton
          \+ dynamic string/int/float holes (the [Needs_string_concat] and [Needs_buffer] tiers).

          [separators] tells the emit function whether adjacent text nodes must be delimited with an [<!-- -->] comment,
          matching react-dom: [render_to_string] needs the delimiters so hydration can split merged text nodes,
          [render_to_static_markup] must not emit them.

          [original] is a thunk that rebuilds the variant-tree form on-demand for [clone_element]. Same name as
          [Static.original] for symmetry; [Writer]'s version is lazy so the render-to-string fast path pays no
          allocation for the fallback. *)
  | Fragment of element
  | Empty
  | Provider of { children : element; push : unit -> unit -> unit }
  | Consumer of element
  | Suspense of { key : string option; children : element; fallback : element option }

and lower_case_element = { key : string option; tag : string; attributes : Jsx.prop list; children : element list }

exception Invalid_children of string

let prop_key (prop : Jsx.prop) =
  match prop with
  | Bool (name, _, _) -> name
  | Booleanish_string (name, _, _) -> name
  | String (name, _, _) -> name
  | Int (name, _, _) -> name
  | Float (name, _, _) -> name
  | Style _ -> "style"
  | Dangerously_inner_html _ -> "dangerouslySetInnerHTML"
  | Ref _ -> "ref"
  | Event (name, _) -> name

(* Merges attributes following JS object-spread semantics ([{...attributes, ...new_attributes}]): base attributes keep
   their original order and are replaced in place when a new attribute shares their key; new attributes with unseen
   keys are appended in their original order. If the same key appears multiple times in [new_attributes], the last
   occurrence wins. O(n²) over List, which is fine: attribute lists are small and [clone_element] is rare. *)
let clone_attributes (attributes : Jsx.prop list) (new_attributes : Jsx.prop list) =
  let key_equals key prop = String.equal (prop_key prop) key in
  let last_new_with_key key =
    List.fold_left (fun acc prop -> if key_equals key prop then Some prop else acc) None new_attributes
  in
  let base =
    List.map
      (fun attr -> match last_new_with_key (prop_key attr) with Some replacement -> replacement | None -> attr)
      attributes
  in
  let rec append_new seen props =
    match props with
    | [] -> []
    | prop :: rest ->
        let key = prop_key prop in
        if List.exists (key_equals key) attributes || List.mem key seen then append_new seen rest
        else
          let winner = match last_new_with_key key with Some last -> last | None -> prop in
          winner :: append_new (key :: seen) rest
  in
  base @ append_new [] new_attributes

let create_element_with_key ?key tag attributes children =
  match Html.is_self_closing_tag tag with
  | true when List.length children > 0 ->
      raise (Invalid_children (Printf.sprintf {|"%s" is a self-closing tag and must not have "children".\n|} tag))
  | true when List.exists (function Jsx.Dangerously_inner_html _ -> true | _ -> false) attributes ->
      raise
        (Invalid_children
           (Printf.sprintf {|"%s" is a self-closing tag and must not have "dangerouslySetInnerHTML".\n|} tag))
  | true -> Lower_case_element { key; tag; attributes; children = [] }
  | false -> Lower_case_element { key; tag; attributes; children }

let create_element = create_element_with_key ?key:None
let create_element_with_key = create_element_with_key

let clone_component_error name =
  Printf.sprintf
    "React.clone_element: cannot clone '%s'. In server-reason-react, component props are compile-time labelled \
     arguments (and extending them with new props at runtime is not supported). React.clone_element only works with \
     lowercase DOM elements."
    name

let rec clone_element element new_attributes =
  match element with
  | Lower_case_element { key; tag; attributes; children } ->
      Lower_case_element { key; tag; attributes = clone_attributes attributes new_attributes; children }
  | Upper_case_component (name, _) -> raise (Invalid_argument (clone_component_error name))
  | Static { original; prerendered = _ } -> clone_element original new_attributes
  | Writer { original; emit = _ } -> clone_element (original ()) new_attributes
  | Fragment _ -> raise (Invalid_argument "React.clone_element: cannot clone a Fragment")
  | Text _ | Int _ | Float _ -> raise (Invalid_argument "React.clone_element: cannot clone a Text element")
  | Empty -> raise (Invalid_argument "React.clone_element: cannot clone a null element")
  | List _ -> raise (Invalid_argument "React.clone_element: cannot clone a List")
  | Array _ -> raise (Invalid_argument "React.clone_element: cannot clone an Array")
  | Provider _ -> raise (Invalid_argument "React.clone_element: cannot clone a Provider")
  | Consumer _ -> raise (Invalid_argument "React.clone_element: cannot clone a Consumer")
  | Suspense _ -> raise (Invalid_argument "React.clone_element: cannot clone a Suspense")

module Fragment = struct
  let make_props ~children () : < children : element > =
    object
      method children = children
    end

  let make ?key:_ props = Fragment props#children
end

let fragment children = Fragment.make (Fragment.make_props ~children ())

(* ReasonReact APIs *)
let string txt = Text txt
let null = Empty
let int i = Int i
let float f = Float f
let array arr = Array arr
let list l = List l

type 'a provider = value:'a -> children:element -> unit -> element

module Context = struct
  type 'a t = { current_value : 'a ref; provider : 'a provider; consumer : children:element -> element }

  let make_props ~value ~children () : < value : 'a ; children : element > =
    object
      method value = value
      method children = children
    end

  let provider ctx ?key:_ props = ctx.provider ~value:props#value ~children:props#children ()
end

let create_context (initial_value : 'a) : 'a Context.t =
  let ref_value = { current = initial_value } in
  let provider ~value ~children () =
    Provider
      {
        children;
        push =
          (fun () ->
            let prev = ref_value.current in
            ref_value.current <- value;
            fun () -> ref_value.current <- prev);
      }
  in
  let consumer ~children = Consumer children in
  { current_value = ref_value; provider; consumer }

module Suspense = struct
  let or_react_null = function None -> null | Some x -> x

  let make_props ?fallback ?children () : < fallback : element option ; children : element option > =
    object
      method fallback = fallback
      method children = children
    end

  let make ?key props = Suspense { key; fallback = props#fallback; children = or_react_null props#children }
end

(* On the server there's no re-render, so memoization is a no-op and the
   component is passed through unchanged. Signatures match reason-react. *)
let memo component = component
let memo_custom_compare_props component _compare = component
let use_context (context : 'a Context.t) = context.current_value.current

let use_state (make_initial_value : unit -> 'state) =
  let initial_value : 'state = make_initial_value () in
  let set_state (fn : 'state -> 'state) =
    let _ = fn initial_value in
    ()
  in
  (initial_value, set_state)

type ('input, 'output) callback = 'input -> 'output

let use_sync_external_store ~subscribe:_ ~get_snapshot = get_snapshot ()
let use_sync_external_store_with_server ~subscribe:_ ~get_snapshot:_ ~get_server_snapshot = get_server_snapshot ()

(* Tree context for use_id — implements the same bit-packing algorithm as React's
   ReactFizzTree_context.js to produce hydration-compatible IDs.

   IDs are base-32 strings whose binary representation corresponds to the
   position of a node in a tree. Every time the tree forks into multiple
   children, additional bits encode the position of the child within the
   current level of children. *)
module Tree_context = struct
  type t = { id : int; overflow : string }

  let empty = { id = 1; overflow = "" }

  let get_bit_length n =
    let rec go bits n = if n = 0 then bits else go (bits + 1) (n lsr 1) in
    go 0 n

  let get_leading_bit id = 1 lsl (get_bit_length id - 1)

  (* Convert a non-negative integer to a base-32 string (digits: 0-9, a-v).
     Matches JavaScript's Number.prototype.toString(32). *)
  let int_to_base32 n =
    if n = 0 then "0"
    else
      let digits = "0123456789abcdefghijklmnopqrstuv" in
      let buf = Buffer.create 8 in
      let rec go n =
        if n > 0 then begin
          go (n / 32);
          Buffer.add_char buf (String.get digits (n mod 32))
        end
      in
      go n;
      Buffer.contents buf

  let get_tree_id ctx =
    let overflow = ctx.overflow in
    let id_with_leading_bit = ctx.id in
    let id = id_with_leading_bit land lnot (get_leading_bit id_with_leading_bit) in
    int_to_base32 id ^ overflow

  let push base_ctx ~total_children ~index =
    let base_id_with_leading_bit = base_ctx.id in
    let base_overflow = base_ctx.overflow in
    let base_length = get_bit_length base_id_with_leading_bit - 1 in
    let base_id = base_id_with_leading_bit land lnot (1 lsl base_length) in
    let slot = index + 1 in
    let length = get_bit_length total_children + base_length in
    if length > 30 then begin
      (* Overflow: convert some bits to base-32 string *)
      let number_of_overflow_bits = base_length - (base_length mod 5) in
      let new_overflow_bits = (1 lsl number_of_overflow_bits) - 1 in
      let new_overflow = int_to_base32 (base_id land new_overflow_bits) in
      let rest_of_base_id = base_id asr number_of_overflow_bits in
      let rest_of_base_length = base_length - number_of_overflow_bits in
      let rest_of_length = get_bit_length total_children + rest_of_base_length in
      let rest_of_new_bits = slot lsl rest_of_base_length in
      let id = rest_of_new_bits lor rest_of_base_id in
      let overflow = new_overflow ^ base_overflow in
      { id = (1 lsl rest_of_length) lor id; overflow }
    end
    else
      (* Normal path *)
      let new_bits = slot lsl base_length in
      let id = new_bits lor base_id in
      { id = (1 lsl length) lor id; overflow = base_overflow }
end

(* Rendering hook context — mutable state set by the renderer (React_dom) and
   read by hooks (use_id). This mirrors React's currentlyRenderingTask pattern
   in ReactFizzHooks.js.

   This state is process-global: renders run synchronously and must not be
   re-entered. *)
let current_tree_context : Tree_context.t Stdlib.ref = Stdlib.ref Tree_context.empty
let local_id_counter : int Stdlib.ref = Stdlib.ref 0
let did_render_id_hook : bool Stdlib.ref = Stdlib.ref false
let identifier_prefix : string option Stdlib.ref = Stdlib.ref None

let reset_component_id_state (ctx : Tree_context.t) =
  current_tree_context := ctx;
  local_id_counter := 0;
  did_render_id_hook := false

let check_did_render_id_hook () = !did_render_id_hook

let reset_id_rendering ?prefix () =
  current_tree_context := Tree_context.empty;
  local_id_counter := 0;
  did_render_id_hook := false;
  identifier_prefix := prefix

(* React 19 uses \u00ab (LEFT-POINTING DOUBLE ANGLE QUOTATION MARK) and
   \u00bb (RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK) as ID delimiters. *)
let id_start = "\xc2\xab"
let id_end = "\xc2\xbb"

let use_id () =
  let tree_id = Tree_context.get_tree_id !current_tree_context in
  let local_id = !local_id_counter in
  local_id_counter := local_id + 1;
  did_render_id_hook := true;
  match (!identifier_prefix, local_id > 0) with
  | None, false -> Printf.sprintf "%sR%s%s" id_start tree_id id_end
  | None, true -> Printf.sprintf "%sR%sH%s%s" id_start tree_id (Tree_context.int_to_base32 local_id) id_end
  | Some prefix, false -> Printf.sprintf "%s%sR%s%s" id_start prefix tree_id id_end
  | Some prefix, true ->
      Printf.sprintf "%s%sR%sH%s%s" id_start prefix tree_id (Tree_context.int_to_base32 local_id) id_end

let use_memo fn = fn ()
let use_memo0 fn = fn ()
let use_memo1 fn _ = fn ()
let use_memo2 fn _ = fn ()
let use_memo3 fn _ = fn ()
let use_memo4 fn _ = fn ()
let use_memo5 fn _ = fn ()
let use_memo6 fn _ = fn ()
let use_callback fn = fn
let use_callback0 fn = fn
let use_callback1 fn _ = fn
let use_callback2 fn _ = fn
let use_callback3 fn _ = fn
let use_callback4 fn _ = fn
let use_callback5 fn _ = fn
let use_callback6 fn _ = fn
let use_reducer _ s = (s, fun _ -> ())
let use_reducer_with_map_state _ s mapper = (mapper s, fun _ -> ())
let use_effect _ = ()
let use_effect0 _ = ()
let use_effect1 _ _ = ()
let use_effect2 _ _ = ()
let use_effect3 _ _ = ()
let use_effect4 _ _ = ()
let use_effect5 _ _ = ()
let use_effect6 _ _ = ()
let use_layout_effect0 _ = ()
let use_layout_effect1 _ _ = ()
let use_layout_effect2 _ _ = ()
let use_layout_effect3 _ _ = ()
let use_layout_effect4 _ _ = ()
let use_layout_effect5 _ _ = ()
let use_layout_effect6 _ _ = ()

module Children = struct
  let map element fn =
    match element with
    | List children -> List.map fn children |> list
    | Array children -> Array.map fn children |> array
    | _ -> fn element

  let map_with_index element fn =
    match element with
    | List children -> List.mapi (fun index element -> fn element index) children |> list
    | Array children -> Array.mapi (fun index element -> fn element index) children |> array
    | _ -> fn element 0

  let for_each element fn =
    match element with
    | List children -> List.iter fn children
    | Array children -> Array.iter fn children
    | _ ->
        let _ = fn element in
        ()

  let for_each_with_index element fn =
    match element with
    | List children -> List.iteri (fun index element -> fn element index) children
    | Array children -> Array.iteri (fun index element -> fn element index) children
    | _ ->
        let _ = fn element 0 in
        ()

  let count element =
    match element with
    | List children -> List.length children
    | Array children -> Array.length children
    | Empty -> 0
    | _ -> 1

  let only element =
    match element with
    | List (child :: _) -> child
    | List [] -> raise (Invalid_argument "Expected at least one child")
    | Array children ->
        if Array.length children >= 1 then Array.get children 0
        else raise (Invalid_argument "Expected at least one child")
    | _ -> element

  (* TODO: silly way to convert children to array, but isn't necessary in most cases *)
  let to_array element = [| element |]
end

let set_display_name _ _ = ()
let use_transition () = (false, fun (_cb : unit -> unit) -> ())
let use_debug_value : 'value -> ?format:('value -> string) -> unit = fun[@warning "-16"] _ ?format:_ -> ()
let use_deferred_value value = value
