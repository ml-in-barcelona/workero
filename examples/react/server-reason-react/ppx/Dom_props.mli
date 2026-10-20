type attribute_type = String | Int | Float | Bool | Booleanish_string | Style | Ref | Inner_html

type event_type =
  | Clipboard
  | Composition
  | Keyboard
  | Focus
  | Form
  | Mouse
  | Selection
  | Touch
  | Ui
  | Wheel
  | Media
  | Image
  | Animation
  | Transition
  | Pointer
  | Inline
  | Drag

type attribute = { type_ : attribute_type; name : string; jsx_name : string; reason_jsx_name : string }
type event = { type_ : event_type; jsx_name : string }
type prop = Attribute of attribute | Event of event
type errors = [ `Element_not_found | `Attribute_not_found ]

val get_jsx_name : prop -> string
val find_by_jsx_name : tag:string -> string -> (prop, errors) result
val find_closest_name : string -> string option
