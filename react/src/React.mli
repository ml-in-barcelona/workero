(** The React library *)

type dom_element
type dom_ref
type 'value ref = { mutable current : 'value }

module Ref : sig
  type t = dom_ref
  type current_dom_ref = dom_element option ref
  type callback_dom_ref = dom_element option -> unit

  val dom_ref : current_dom_ref -> t
  val callback_dom_ref : callback_dom_ref -> t
end

val create_ref : unit -> 'a option ref
val use_ref : 'a -> 'a ref
val forward_ref : (unit -> 'a) -> 'a

module Event : sig
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

  module Make_event_with_type : functor
    (Type : sig
       type t
     end)
    -> sig
    val bubbles : Type.t -> bool
    val cancelable : Type.t -> bool
    val current_target : Type.t -> target_like
    val default_prevented : Type.t -> bool
    val event_phase : Type.t -> int
    val is_trusted : Type.t -> bool
    val native_event : Type.t -> target_like
    val prevent_default : Type.t -> unit
    val is_default_prevented : Type.t -> bool
    val stop_propagation : Type.t -> unit
    val is_propagation_stopped : Type.t -> bool
    val target : Type.t -> target_like
    val time_stamp : Type.t -> float
    val type_ : Type.t -> string
    val persist : Type.t -> unit
  end

  module Synthetic : sig
    type tag
    type t = tag synthetic

    val bubbles : 'a synthetic -> bool
    val cancelable : 'a synthetic -> bool
    val current_target : 'a synthetic -> target_like
    val default_prevented : 'a synthetic -> bool
    val event_phase : 'a synthetic -> int
    val is_trusted : 'a synthetic -> bool
    val native_event : 'a synthetic -> target_like
    val prevent_default : 'a synthetic -> unit
    val is_default_prevented : 'a synthetic -> bool
    val stop_propagation : 'a synthetic -> unit
    val is_propagation_stopped : 'a synthetic -> bool
    val target : 'a synthetic -> target_like
    val time_stamp : 'a synthetic -> float
    val type_ : 'a synthetic -> string
    val persist : 'a synthetic -> unit
  end

  module Clipboard : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
    val clipboard_data : t -> target_like
  end

  module Composition : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
    val data : t -> string
  end

  module Keyboard : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
    val alt_key : t -> bool
    val char_code : t -> int
    val ctrl_key : t -> bool
    val get_modifier_state : t -> string -> bool
    val key : t -> string
    val key_code : t -> int
    val locale : t -> string
    val location : t -> int
    val meta_key : t -> bool
    val repeat : t -> bool
    val shift_key : t -> bool
    val which : t -> int
  end

  module Focus : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
    val related_target : t -> target_like option
  end

  module Form : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
  end

  module Mouse : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
    val alt_key : t -> bool
    val button : t -> int
    val buttons : t -> int
    val client_x : t -> int
    val client_y : t -> int
    val ctrl_key : t -> bool
    val get_modifier_state : t -> string -> bool
    val meta_key : t -> bool
    val movement_x : t -> int
    val movement_y : t -> int
    val page_x : t -> int
    val page_y : t -> int
    val related_target : t -> target_like option
    val screen_x : t -> int
    val screen_y : t -> int
    val shift_key : t -> bool
  end

  module Pointer : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
    val detail : t -> int
    val screen_x : t -> int
    val screen_y : t -> int
    val client_x : t -> int
    val client_y : t -> int
    val page_x : t -> int
    val page_y : t -> int
    val movement_x : t -> int
    val movement_y : t -> int
    val ctrl_key : t -> bool
    val shift_key : t -> bool
    val alt_key : t -> bool
    val meta_key : t -> bool
    val get_modifier_state : t -> string -> bool
    val button : t -> int
    val buttons : t -> int
    val related_target : t -> target_like option
    val width : t -> float
    val height : t -> float
    val pressure : t -> float
    val tangential_pressure : t -> float
    val tilt_x : t -> int
    val tilt_y : t -> int
    val twist : t -> int
    val pointer_type : t -> string
    val is_primary : t -> bool
  end

  module Selection : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
  end

  module Touch : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
    val alt_key : t -> bool
    val changed_touches : t -> target_like
    val ctrl_key : t -> bool
    val get_modifier_state : t -> string -> bool
    val meta_key : t -> bool
    val shift_key : t -> bool
    val target_touches : t -> target_like
    val touches : t -> target_like
  end

  module Ui : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
    val detail : t -> int
  end

  module Wheel : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
    val delta_mode : t -> int
    val delta_x : t -> float
    val delta_y : t -> float
    val delta_z : t -> float
  end

  module Media : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
  end

  module Image : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
  end

  module Animation : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
    val animation_name : t -> string
    val pseudo_element : t -> string
    val elapsed_time : t -> float
  end

  module Transition : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
    val property_name : t -> string
    val pseudo_element : t -> string
    val elapsed_time : t -> float
  end

  module Drag : sig
    type tag
    type t = tag synthetic

    val bubbles : t -> bool
    val cancelable : t -> bool
    val current_target : t -> target_like
    val default_prevented : t -> bool
    val event_phase : t -> int
    val is_trusted : t -> bool
    val native_event : t -> target_like
    val prevent_default : t -> unit
    val is_default_prevented : t -> bool
    val stop_propagation : t -> unit
    val is_propagation_stopped : t -> bool
    val target : t -> target_like
    val time_stamp : t -> float
    val type_ : t -> string
    val persist : t -> unit
    val alt_key : t -> bool
    val button : t -> int
    val buttons : t -> int
    val client_x : t -> int
    val client_y : t -> int
    val ctrl_key : t -> bool
    val get_modifier_state : t -> string -> bool
    val meta_key : t -> bool
    val movement_x : t -> int
    val movement_y : t -> int
    val page_x : t -> int
    val page_y : t -> int
    val related_target : t -> target_like option
    val screen_x : t -> int
    val screen_y : t -> int
    val shift_key : t -> bool
    val data_transfer : t -> target_like
  end
end

(** All of those types are used by the server-reason-react.ppx internally to represent valid React code from the server.
    It currently different from reason-react-ppx due to a need for knowing the types since React_dom needs to render
    differently depending on the type. *)
module Jsx : sig
  (** All event callbacks *)
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

  (** Jsx.prop is the representation of HTML/SVG attributes and DOM events *)
  type prop =
    | Bool of (string * string * bool)
    | Booleanish_string of (string * string * bool)
    | String of (string * string * string)
    | Int of (string * string * int)
    | Float of (string * string * float)
    | Style of (string * string * string) list
    | Dangerously_inner_html of string
    | Ref of dom_ref
    | Event of string * event

  (** Helpers to create Jsx.prop without variants, helpful for function application *)

  val bool : string -> string -> bool -> prop
  val booleanish_string : string -> string -> bool -> prop
  val string : string -> string -> string -> prop
  val style : (string * string * string) list -> prop
  val dangerously_inner_html : < __html : string ; .. > -> prop
  val int : string -> string -> int -> prop
  val float : string -> string -> float -> prop
  val ref : dom_ref -> prop
  val event : string -> event -> prop

  module Event : sig
    val drag : string -> (Event.Drag.t -> unit) -> prop
    val mouse : string -> (Event.Mouse.t -> unit) -> prop
    val selection : string -> (Event.Selection.t -> unit) -> prop
    val touch : string -> (Event.Touch.t -> unit) -> prop
    val ui : string -> (Event.Ui.t -> unit) -> prop
    val wheel : string -> (Event.Wheel.t -> unit) -> prop
    val clipboard : string -> (Event.Clipboard.t -> unit) -> prop
    val composition : string -> (Event.Composition.t -> unit) -> prop
    val transition : string -> (Event.Transition.t -> unit) -> prop
    val animation : string -> (Event.Animation.t -> unit) -> prop
    val pointer : string -> (Event.Pointer.t -> unit) -> prop
    val keyboard : string -> (Event.Keyboard.t -> unit) -> prop
    val focus : string -> (Event.Focus.t -> unit) -> prop
    val form : string -> (Event.Form.t -> unit) -> prop
    val media : string -> (Event.Media.t -> unit) -> prop
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
      (** Subtree with static skeleton + dynamic string/int/float/element holes. [emit] writes directly into the
          caller's buffer, avoiding the intermediate buffer + Buffer.contents allocation that a [Static] wrapping would
          require.

          [separators] tells the emit function whether adjacent text nodes must be delimited with an [<!-- -->] comment,
          matching react-dom: [render_to_string] needs the delimiters so hydration can split merged text nodes,
          [render_to_static_markup] must not emit them.

          [original] is a thunk that rebuilds the variant-tree form on-demand for [clone_element]. Same name as
          [Static.original] for symmetry; this variant's version is lazy. Emitted by the PPX for the
          [Needs_string_concat] and [Needs_buffer] analysis tiers. *)
  | Fragment of element
  | Empty
  | Provider of { children : element; push : unit -> unit -> unit }
  | Consumer of element
  | Suspense of { key : string option; children : element; fallback : element option }

and lower_case_element = { key : string option; tag : string; attributes : Jsx.prop list; children : element list }

exception Invalid_children of string

module Fragment : sig
  val make_props : children:element -> unit -> < children : element >
  val make : (< children : element >, element) component_like
end

val create_element : string -> Jsx.prop list -> element list -> element
val create_element_with_key : ?key:string -> string -> Jsx.prop list -> element list -> element
val fragment : element -> element
val clone_element : element -> Jsx.prop list -> element
val string : string -> element
val null : element
val int : int -> element
val float : float -> element
val array : element array -> element
val list : element list -> element

type 'a provider = value:'a -> children:element -> unit -> element

module Context : sig
  type 'a t = { current_value : 'a ref; provider : 'a provider; consumer : children:element -> element }

  val make_props : value:'a -> children:element -> unit -> < value : 'a ; children : element >
  val provider : 'a t -> (< value : 'a ; children : element >, element) component_like
end

val create_context : 'a -> 'a Context.t

module Suspense : sig
  val make_props :
    ?fallback:element -> ?children:element -> unit -> < fallback : element option ; children : element option >

  val make : (< fallback : element option ; children : element option >, element) component_like
end

(** Signatures match reason-react. On the server there's no re-render, so memoization is a no-op: the component is
    returned unchanged and the compare function is ignored. *)

val memo : 'component -> 'component
val memo_custom_compare_props : 'component -> ('props -> 'props -> bool) -> 'component
val use_context : 'a Context.t -> 'a
val use_state : (unit -> 'state) -> 'state * (('state -> 'state) -> unit)
val use_memo : (unit -> 'a) -> 'a
val use_memo0 : (unit -> 'a) -> 'a
val use_memo1 : (unit -> 'a) -> 'b -> 'a
val use_memo2 : (unit -> 'a) -> 'b -> 'a
val use_memo3 : (unit -> 'a) -> 'b -> 'a
val use_memo4 : (unit -> 'a) -> 'b -> 'a
val use_memo5 : (unit -> 'a) -> 'b -> 'a
val use_memo6 : (unit -> 'a) -> 'b -> 'a
val use_callback : 'a -> 'a
val use_callback0 : 'a -> 'a
val use_callback1 : 'a -> 'b -> 'a
val use_callback2 : 'a -> 'b -> 'a
val use_callback3 : 'a -> 'b -> 'a
val use_callback4 : 'a -> 'b -> 'a
val use_callback5 : 'a -> 'b -> 'a
val use_callback6 : 'a -> 'b -> 'a

module Tree_context : sig
  type t

  val empty : t
  val push : t -> total_children:int -> index:int -> t
end

val current_tree_context : Tree_context.t Stdlib.ref
(** Rendering hook context — called by the renderer before/after rendering each function component.

    Process-global: renders run synchronously and must not be re-entered. *)

val reset_component_id_state : Tree_context.t -> unit
val check_did_render_id_hook : unit -> bool
val reset_id_rendering : ?prefix:string -> unit -> unit

val use_id : unit -> string
(** Generates a stable id for the current render.

    Relies on process-global state ([current_tree_context] et al.). *)

type ('input, 'output) callback = 'input -> 'output

val use_sync_external_store :
  subscribe:((unit -> unit) -> (unit, unit) callback) -> get_snapshot:(unit -> 'snapshot) -> 'snapshot
[@@deprecated "Use useSyncExternalStoreWithServer instead"]

val use_sync_external_store_with_server :
  subscribe:((unit -> unit) -> (unit, unit) callback) ->
  get_snapshot:(unit -> 'snapshot) ->
  get_server_snapshot:(unit -> 'snapshot) ->
  'snapshot

val use_reducer : ('state -> 'action -> 'state) -> 'state -> 'state * ('action -> unit)

val use_reducer_with_map_state :
  ('state -> 'action -> 'initial_state) -> 'initial_state -> ('initial_state -> 'state) -> 'state * ('action -> unit)

val use_effect : (unit -> (unit -> unit) option) -> unit
val use_effect0 : (unit -> (unit -> unit) option) -> unit
val use_effect1 : (unit -> (unit -> unit) option) -> 'dependency array -> unit
val use_effect2 : (unit -> (unit -> unit) option) -> 'dependency1 * 'dependency2 -> unit
val use_effect3 : (unit -> (unit -> unit) option) -> 'dependency1 * 'dependency2 * 'dependency3 -> unit
val use_effect4 : (unit -> (unit -> unit) option) -> 'dependency1 * 'dependency2 * 'dependency3 * 'dependency4 -> unit

val use_effect5 :
  (unit -> (unit -> unit) option) -> 'dependency1 * 'dependency2 * 'dependency3 * 'dependency4 * 'dependency5 -> unit

val use_effect6 :
  (unit -> (unit -> unit) option) ->
  'dependency1 * 'dependency2 * 'dependency3 * 'dependency4 * 'dependency5 * 'dependency6 ->
  unit

val use_layout_effect0 : (unit -> (unit -> unit) option) -> unit
val use_layout_effect1 : (unit -> (unit -> unit) option) -> 'dependency array -> unit
val use_layout_effect2 : (unit -> (unit -> unit) option) -> 'dependency1 * 'dependency2 -> unit
val use_layout_effect3 : (unit -> (unit -> unit) option) -> 'dependency1 * 'dependency2 * 'dependency3 -> unit

val use_layout_effect4 :
  (unit -> (unit -> unit) option) -> 'dependency1 * 'dependency2 * 'dependency3 * 'dependency4 -> unit

val use_layout_effect5 :
  (unit -> (unit -> unit) option) -> 'dependency1 * 'dependency2 * 'dependency3 * 'dependency4 * 'dependency5 -> unit

val use_layout_effect6 :
  (unit -> (unit -> unit) option) ->
  'dependency1 * 'dependency2 * 'dependency3 * 'dependency4 * 'dependency5 * 'dependency6 ->
  unit

val set_display_name : 'component -> string -> unit

module Children : sig
  val map : element -> (element -> element) -> element
  val map_with_index : element -> (element -> int -> element) -> element
  val for_each : element -> (element -> unit) -> unit
  val for_each_with_index : element -> (element -> int -> unit) -> unit
  val count : element -> int
  val only : element -> element
  val to_array : element -> element array
end

val use_transition : unit -> bool * ((unit -> unit) -> unit)
val use_debug_value : 'value -> ?format:('value -> string) -> unit
val use_deferred_value : 'value -> 'value
