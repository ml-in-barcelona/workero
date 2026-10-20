[@@@ocamlformat "disable"]
(* This file is more like a spreadsheet, prefer to keep it with margin=300.
   Since @@@ocamlformat "margin=300" isn't possible, we disable it *)

type attribute_type =
  | String
  | Int
  | Float
  | Bool
  | Booleanish_string (* `Booleanish_string` are Jsx attributes represented as boolean values but rendered as strings on HTML https://github.com/facebook/react/blob/a17467e7e2cd8947c595d1834889b5d184459f12/packages/react-dom-bindings/src/server/ReactFizzConfigDOM.js#L1165-L1176 *)
  | Style
  | Ref
  | Inner_html

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

(* In React, all DOM properties and attributes (including event handlers) should be camelCased. For example, the HTML attribute tabindex corresponds to the attribute tab_index in React. The exception is aria-* and data-* attributes, which should be lowercased. For example, you can keep aria-label as aria-label.
  More info about it: https://legacy.reactjs.org/docs/dom-elements.html *)
(* In `attribute` we store the 3 formats for DOM (HTML and SVG) attributes, Jsx props and Reason's Jsx props *)
type attribute = {
  type_ : attribute_type;
  name : string; (* HTML name *)
  jsx_name : string; (* Jsx name *)
  reason_jsx_name : string; (* Reason's Jsx name is the format that appears on Reason/OCaml files, which are must not
  match with reserved keywords from OCaml (https://ocaml.org/manual/5.2/lex.html#sss:keywords) or Reason syntax (https://github.com/reasonml/reason/blob/master/src/reason-parser/reason_declarative_lexer.mll#L85-L144).
  Currently all reserved words used in HTML come from OCaml (and inheritly in Reason), but there's none that comes from Reason. *)
}

type event = {
  type_ : event_type;
  (* event handlers should be camelCased and they don't collied with any reserved words from the language.
     also we don't use the HTML format in the ppx, neither int the runtime *)
  jsx_name : string;
}

type prop =
  | Attribute of attribute
  | Event of event

type element = {
  tag : string;
  attributes : prop list;
}

let attribute_referrer_policy = String
(* | Empty | NoReferrer | NoReferrerWhenDowngrade | Origin |
   OriginWhenCrossOrigin | SameOrigin | StrictOrigin |
   StrictOriginWhenCrossOrigin | UnsafeUrl *)

let attribute_anchor_target = String
(* | Self | Blank | Parent | Top | Custom of String *)

let global_event_handlers =
  (* https://developer.mozilla.org/en-US/docs/Web/Events/Event_handlers *)
  [
    Event { jsx_name = "on_copy"; type_ = Clipboard };
    Event { jsx_name = "on_copy_capture"; type_ = Clipboard };
    Event { jsx_name = "on_cut"; type_ = Clipboard };
    Event { jsx_name = "on_cut_capture"; type_ = Clipboard };
    Event { jsx_name = "on_paste"; type_ = Clipboard };
    Event { jsx_name = "on_paste_capture"; type_ = Clipboard };
    Event { jsx_name = "on_composition_end"; type_ = Composition };
    Event { jsx_name = "on_composition_end_capture"; type_ = Composition };
    Event { jsx_name = "on_composition_start"; type_ = Composition };
    Event { jsx_name = "on_composition_start_capture"; type_ = Composition };
    Event { jsx_name = "on_composition_update"; type_ = Composition };
    Event { jsx_name = "on_composition_update_capture"; type_ = Composition };
    Event { jsx_name = "on_focus"; type_ = Focus };
    Event { jsx_name = "on_focus_capture"; type_ = Focus };
    Event { jsx_name = "on_blur"; type_ = Focus };
    Event { jsx_name = "on_blur_capture"; type_ = Focus };
    Event { jsx_name = "on_change"; type_ = Form };
    Event { jsx_name = "on_change_capture"; type_ = Form };
    Event { jsx_name = "on_before_input"; type_ = Form };
    Event { jsx_name = "on_before_input_capture"; type_ = Form };
    Event { jsx_name = "on_input"; type_ = Form };
    Event { jsx_name = "on_input_capture"; type_ = Form };
    Event { jsx_name = "on_reset"; type_ = Form };
    Event { jsx_name = "on_reset_capture"; type_ = Form };
    Event { jsx_name = "on_submit"; type_ = Form };
    Event { jsx_name = "on_submit_capture"; type_ = Form };
    Event { jsx_name = "on_invalid"; type_ = Form };
    Event { jsx_name = "on_invalid_capture"; type_ = Form };
    Event { jsx_name = "on_load"; type_ = Media };
    Event { jsx_name = "on_load_capture"; type_ = Media };
    Event { jsx_name = "on_error"; type_ = Media };
    Event { jsx_name = "on_error_capture"; type_ = Media };
    Event { jsx_name = "on_key_down"; type_ = Keyboard };
    Event { jsx_name = "on_key_down_capture"; type_ = Keyboard };
    Event { jsx_name = "on_key_press"; type_ = Keyboard };
    Event { jsx_name = "on_key_press_capture"; type_ = Keyboard };
    Event { jsx_name = "on_key_up"; type_ = Keyboard };
    Event { jsx_name = "on_key_up_capture"; type_ = Keyboard };
    Event { jsx_name = "on_abort"; type_ = Media };
    Event { jsx_name = "on_abort_capture"; type_ = Media };
    Event { jsx_name = "on_can_play"; type_ = Media };
    Event { jsx_name = "on_can_play_capture"; type_ = Media };
    Event { jsx_name = "on_can_play_through"; type_ = Media };
    Event { jsx_name = "on_can_play_through_capture"; type_ = Media };
    Event { jsx_name = "on_duration_change"; type_ = Media };
    Event { jsx_name = "on_duration_change_capture"; type_ = Media };
    Event { jsx_name = "on_emptied"; type_ = Media };
    Event { jsx_name = "on_emptied_capture"; type_ = Media };
    Event { jsx_name = "on_encrypted"; type_ = Media };
    Event { jsx_name = "on_encrypted_capture"; type_ = Media };
    Event { jsx_name = "on_ended"; type_ = Media };
    Event { jsx_name = "on_ended_capture"; type_ = Media };
    Event { jsx_name = "on_loaded_data"; type_ = Media };
    Event { jsx_name = "on_loaded_data_capture"; type_ = Media };
    Event { jsx_name = "on_loaded_metadata"; type_ = Media };
    Event { jsx_name = "on_loaded_metadata_capture"; type_ = Media };
    Event { jsx_name = "on_load_start"; type_ = Media };
    Event { jsx_name = "on_load_start_capture"; type_ = Media };
    Event { jsx_name = "on_pause"; type_ = Media };
    Event { jsx_name = "on_pause_capture"; type_ = Media };
    Event { jsx_name = "on_play"; type_ = Media };
    Event { jsx_name = "on_play_capture"; type_ = Media };
    Event { jsx_name = "on_playing"; type_ = Media };
    Event { jsx_name = "on_playing_capture"; type_ = Media };
    Event { jsx_name = "on_progress"; type_ = Media };
    Event { jsx_name = "on_progress_capture"; type_ = Media };
    Event { jsx_name = "on_rate_change"; type_ = Media };
    Event { jsx_name = "on_rate_change_capture"; type_ = Media };
    Event { jsx_name = "on_seeked"; type_ = Media };
    Event { jsx_name = "on_seeked_capture"; type_ = Media };
    Event { jsx_name = "on_seeking"; type_ = Media };
    Event { jsx_name = "on_seeking_capture"; type_ = Media };
    Event { jsx_name = "on_stalled"; type_ = Media };
    Event { jsx_name = "on_stalled_capture"; type_ = Media };
    Event { jsx_name = "on_suspend"; type_ = Media };
    Event { jsx_name = "on_suspend_capture"; type_ = Media };
    Event { jsx_name = "on_time_update"; type_ = Media };
    Event { jsx_name = "on_time_update_capture"; type_ = Media };
    Event { jsx_name = "on_volume_change"; type_ = Media };
    Event { jsx_name = "on_volume_change_capture"; type_ = Media };
    Event { jsx_name = "on_waiting"; type_ = Media };
    Event { jsx_name = "on_waiting_capture"; type_ = Media };
    Event { jsx_name = "on_aux_click"; type_ = Mouse };
    Event { jsx_name = "on_aux_click_capture"; type_ = Mouse };
    Event { jsx_name = "on_click"; type_ = Mouse };
    Event { jsx_name = "on_click_capture"; type_ = Mouse };
    Event { jsx_name = "on_context_menu"; type_ = Mouse };
    Event { jsx_name = "on_context_menu_capture"; type_ = Mouse };
    Event { jsx_name = "on_double_click"; type_ = Mouse };
    Event { jsx_name = "on_double_click_capture"; type_ = Mouse };
    Event { jsx_name = "on_drag"; type_ = Drag };
    Event { jsx_name = "on_drag_capture"; type_ = Drag };
    Event { jsx_name = "on_drag_end"; type_ = Drag };
    Event { jsx_name = "on_drag_end_capture"; type_ = Drag };
    Event { jsx_name = "on_drag_enter"; type_ = Drag };
    Event { jsx_name = "on_drag_enter_capture"; type_ = Drag };
    Event { jsx_name = "on_drag_exit"; type_ = Drag };
    Event { jsx_name = "on_drag_exit_capture"; type_ = Drag };
    Event { jsx_name = "on_drag_leave"; type_ = Drag };
    Event { jsx_name = "on_drag_leave_capture"; type_ = Drag };
    Event { jsx_name = "on_drag_over"; type_ = Drag };
    Event { jsx_name = "on_drag_over_capture"; type_ = Drag };
    Event { jsx_name = "on_drag_start"; type_ = Drag };
    Event { jsx_name = "on_drag_start_capture"; type_ = Drag };
    Event { jsx_name = "on_drop"; type_ = Drag };
    Event { jsx_name = "on_drop_capture"; type_ = Drag };
    Event { jsx_name = "on_mouse_down"; type_ = Mouse };
    Event { jsx_name = "on_mouse_down_capture"; type_ = Mouse };
    Event { jsx_name = "on_mouse_enter"; type_ = Mouse };
    Event { jsx_name = "on_mouse_leave"; type_ = Mouse };
    Event { jsx_name = "on_mouse_move"; type_ = Mouse };
    Event { jsx_name = "on_mouse_move_capture"; type_ = Mouse };
    Event { jsx_name = "on_mouse_out"; type_ = Mouse };
    Event { jsx_name = "on_mouse_out_capture"; type_ = Mouse };
    Event { jsx_name = "on_mouse_over"; type_ = Mouse };
    Event { jsx_name = "on_mouse_over_capture"; type_ = Mouse };
    Event { jsx_name = "on_mouse_up"; type_ = Mouse };
    Event { jsx_name = "on_mouse_up_capture"; type_ = Mouse };
    Event { jsx_name = "on_select"; type_ = Selection };
    Event { jsx_name = "on_select_capture"; type_ = Selection };
    Event { jsx_name = "on_touch_cancel"; type_ = Touch };
    Event { jsx_name = "on_touch_cancel_capture"; type_ = Touch };
    Event { jsx_name = "on_touch_end"; type_ = Touch };
    Event { jsx_name = "on_touch_end_capture"; type_ = Touch };
    Event { jsx_name = "on_touch_move"; type_ = Touch };
    Event { jsx_name = "on_touch_move_capture"; type_ = Touch };
    Event { jsx_name = "on_touch_start"; type_ = Touch };
    Event { jsx_name = "on_touch_start_capture"; type_ = Touch };
    Event { jsx_name = "on_pointer_down"; type_ = Pointer };
    Event { jsx_name = "on_pointer_down_capture"; type_ = Pointer };
    Event { jsx_name = "on_pointer_move"; type_ = Pointer };
    Event { jsx_name = "on_pointer_move_capture"; type_ = Pointer };
    Event { jsx_name = "on_pointer_up"; type_ = Pointer };
    Event { jsx_name = "on_pointer_up_capture"; type_ = Pointer };
    Event { jsx_name = "on_pointer_cancel"; type_ = Pointer };
    Event { jsx_name = "on_pointer_cancel_capture"; type_ = Pointer };
    Event { jsx_name = "on_pointer_enter"; type_ = Pointer };
    Event { jsx_name = "on_pointer_enter_capture"; type_ = Pointer };
    Event { jsx_name = "on_pointer_leave"; type_ = Pointer };
    Event { jsx_name = "on_pointer_leave_capture"; type_ = Pointer };
    Event { jsx_name = "on_pointer_over"; type_ = Pointer };
    Event { jsx_name = "on_pointer_over_capture"; type_ = Pointer };
    Event { jsx_name = "on_pointer_out"; type_ = Pointer };
    Event { jsx_name = "on_pointer_out_capture"; type_ = Pointer };
    Event { jsx_name = "on_got_pointer_capture"; type_ = Pointer };
    Event { jsx_name = "on_got_pointer_capture_capture"; type_ = Pointer };
    Event { jsx_name = "on_lost_pointer_capture"; type_ = Pointer };
    Event { jsx_name = "on_lost_pointer_capture_capture"; type_ = Pointer };
    Event { jsx_name = "on_scroll"; type_ = Ui };
    Event { jsx_name = "on_scroll_capture"; type_ = Ui };
    Event { jsx_name = "on_wheel"; type_ = Wheel };
    Event { jsx_name = "on_wheel_capture"; type_ = Wheel };
    Event { jsx_name = "on_animation_start"; type_ = Animation };
    Event { jsx_name = "on_animation_start_capture"; type_ = Animation };
    Event { jsx_name = "on_animation_end"; type_ = Animation };
    Event { jsx_name = "on_animation_end_capture"; type_ = Animation };
    Event { jsx_name = "on_animation_iteration"; type_ = Animation };
    Event { jsx_name = "on_animation_iteration_capture"; type_ = Animation };
    Event { jsx_name = "on_transition_end"; type_ = Transition };
    Event { jsx_name = "on_transition_end_capture"; type_ = Transition };
  ]

(* All the WAI-ARIA 1.1 attributes from https://www.w3.org/TR/wai-aria-1.1/ *)
let aria_attributes =
  [
    (* Identifies the currently active element when DOM focus is on a composite
       widget, textbox, group, or application. *)
    Attribute { name = "aria-activedescendant"; jsx_name = "aria-activedescendant"; reason_jsx_name = "aria_activedescendant"; type_ = String };

    (* Indicates whether assistive technologies will present all, or only parts
       of, the changed region based on the change notifications defined by the
       aria-relevant attribute. *)
    Attribute { name = "aria-atomic"; jsx_name = "aria-atomic"; reason_jsx_name = "aria_atomic"; type_ = Booleanish_string };

    (* Indicates whether inputting text could trigger display of one or more predictions of the user's intended value for an input and specifies how predictions would be
     * presented if they are made.
     *)
    Attribute { name = "aria-autocomplete"; jsx_name = "aria-autocomplete"; reason_jsx_name = "aria_autocomplete"; type_ = String (* 'none' | 'inline' | 'list' | 'both' *) };

    (* Indicates an element is being modified and that assistive technologies
       MAY want to wait until the modifications are complete before exposing
       them to the user. *)
    Attribute { name = "aria-busy"; jsx_name = "aria-busy"; reason_jsx_name = "aria_busy"; type_ = Booleanish_string };

    (* Indicates the current "checked" state of checkboxes, radio buttons, and other
    widgets.
    * @see aria-pressed @see aria-selected.
    *)
    Attribute { name = "aria-checked"; jsx_name = "aria-checked"; reason_jsx_name = "aria_checked"; type_ = String (* Bool | 'false' | 'mixed' | 'true' *) };

    (* Defines the total number of columns in a table, grid, or treegrid.
    * @see aria-colindex.
    *)
    Attribute { name = "aria-colcount"; jsx_name = "aria-colcount"; reason_jsx_name = "aria_colcount"; type_ = Int };

    (* Defines an element's column index or position with respect to the total number of columns within a table,
    grid, or treegrid.
    * @see aria-colcount @see aria-colspan.
    *)
    Attribute { name = "aria-colindex"; jsx_name = "aria-colindex"; reason_jsx_name = "aria_colindex"; type_ = Int };

    (* Defines the number of columns spanned by a cell or gridcell within a table, grid, or treegrid.
    * @see aria-colindex @see aria-rowspan.
    *)
    Attribute { name = "aria-colspan"; jsx_name = "aria-colspan"; reason_jsx_name = "aria_colspan"; type_ = Int };

    (* Identifies the element (or elements) whose contents or presence are controlled by the current element.
    * @see aria-owns.
    *)
    Attribute { name = "aria-controls"; jsx_name = "aria-controls"; reason_jsx_name = "aria_controls"; type_ = String };

    (* Indicates the element that represents the current item within a container
       or set of related elements. *)
    Attribute { name = "aria-current"; jsx_name = "aria-current"; reason_jsx_name = "aria_current"; type_ = String (* Bool | 'false' | 'true' | 'page' | 'step' | 'location' | 'date' | 'time' *) };

    (* Identifies the element (or elements) that describes the object.
     * @see aria-labelledby
     *)
    Attribute { name = "aria-describedby"; jsx_name = "aria-describedby"; reason_jsx_name = "aria_describedby"; type_ = String };

    (* Identifies the element that provides a detailed, extended description for
       the object. * @see aria-describedby. *)
    Attribute { name = "aria-details"; jsx_name = "aria-details"; reason_jsx_name = "aria_details"; type_ = String };

    (* Indicates that the element is perceivable but disabled, so it is not editable or otherwise operable.
    * @see aria-hidden @see aria-readonly.
    *)
    Attribute { name = "aria-disabled"; jsx_name = "aria-disabled"; reason_jsx_name = "aria_disabled"; type_ = Booleanish_string };

    (* Identifies the element that provides an error message for the object.
    * @see aria-invalid @see aria-describedby.
    *)
    Attribute { name = "aria-errormessage"; jsx_name = "aria-errormessage"; reason_jsx_name = "aria_errormessage"; type_ = String };

    (* Indicates whether the element, or another grouping element it controls,
       is currently expanded or collapsed. *)
    Attribute { name = "aria-expanded"; jsx_name = "aria-expanded"; reason_jsx_name = "aria_expanded"; type_ = Booleanish_string };

    (* Identifies the next element (or elements) in an alternate reading order of content which, at the user's discretion,
     * allows assistive technology to override the general default of reading in document source order.
     *)
    Attribute { name = "aria-flowto"; jsx_name = "aria-flowto"; reason_jsx_name = "aria_flowto"; type_ = String };

    (* Indicates the availability and type of interactive popup element, such as
       menu or dialog, that can be triggered by an element. *)
    Attribute { name = "aria-haspopup"; jsx_name = "aria-haspopup"; reason_jsx_name = "aria_haspopup"; type_ = String (* Bool | 'false' | 'true' | 'menu' | 'listbox' | 'tree' | 'grid' | 'dialog'; *)};

    (* Indicates whether the element is exposed to an accessibility API.
     * @see aria-disabled.
     *)
    Attribute { name = "aria-hidden"; jsx_name = "aria-hidden"; reason_jsx_name = "aria_hidden"; type_ = Booleanish_string };

    (* Indicates the entered value does not conform to the format expected by the
    application.
    * @see aria-errormessage.
    *)
    Attribute { name = "aria-invalid"; jsx_name = "aria-invalid"; reason_jsx_name = "aria_invalid"; type_ = String (* Bool | 'false' | 'true' | 'grammar' | 'spelling'; *) };

    (* Indicates keyboard shortcuts that an author has implemented to activate
       or give focus to an element. *)
    Attribute { name = "aria-keyshortcuts"; jsx_name = "aria-keyshortcuts"; reason_jsx_name = "aria_keyshortcuts"; type_ = String };

    (* Defines a String value that labels the current element.
    * @see aria-labelledby.
    *)
    Attribute { name = "aria-label"; jsx_name = "aria-label"; reason_jsx_name = "aria_label"; type_ = String };

    (* Identifies the element (or elements) that labels the current element.
    * @see aria-describedby.
    *)
    Attribute { name = "aria-labelledby"; jsx_name = "aria-labelledby"; reason_jsx_name = "aria_labelledby"; type_ = String };

    (* Defines the hierarchical level of an element within a structure. *)
    Attribute { name = "aria-level"; jsx_name = "aria-level"; reason_jsx_name = "aria_level"; type_ = Int };

    (* Indicates that an element will be updated, and describes the types of
       updates the user agents, assistive technologies, and user can expect ;rom
       the live region. *)
    Attribute { name = "aria-live"; jsx_name = "aria-live"; reason_jsx_name = "aria_live"; type_ = String (* 'off' | 'assertive' | 'polite' *) };

    (* Indicates whether an element is modal when displayed. *)

    Attribute { name = "aria-modal"; jsx_name = "aria-modal"; reason_jsx_name = "aria_modal"; type_ = Booleanish_string };

    (* Indicates whether a text box accepts multiple lines of input or only a
       single line. *)
    Attribute { name = "aria-multiline"; jsx_name = "aria-multiline"; reason_jsx_name = "aria_multiline"; type_ = Booleanish_string };

    (* Indicates that the user may select more than one item from the current
       selectable descendants. *)
    Attribute { name = "aria-multiselectable"; jsx_name = "aria-multiselectable"; reason_jsx_name = "aria_multiselectable"; type_ = Booleanish_string };

    (* Indicates whether the element's orientation is horizontal, vertical, or
       unknown/ambiguous. *)
    Attribute { name = "aria-orientation"; jsx_name = "aria-orientation"; reason_jsx_name = "aria_orientation"; type_ = String (* 'horizontal' | 'vertical' *) };

    (* Identifies an element (or elements) in order to define a visual, functional, or contextual parent/child relationship
     * between DOM elements where the DOM hierarchy cannot be used to represent the relationship.
     * @see aria-controls.
     *)
    Attribute { name = "aria-owns"; jsx_name = "aria-owns"; reason_jsx_name = "aria_owns"; type_ = String };

    (* Defines a short hint (a word or short phrase) intended to aid the user with data entry when the control has no
    value.
    * A hint could be a sample value or a brief description of the expected format.
    *)
    Attribute { name = "aria-placeholder"; jsx_name = "aria-placeholder"; reason_jsx_name = "aria_placeholder"; type_ = String };

    (* Defines an element's number or position in the current set of listitems
       or treeitems. Not required if all elements in the set are present in the
       DOM. * @see aria-setsize. *)
    Attribute { name = "aria-posinset"; jsx_name = "aria-posinset"; reason_jsx_name = "aria_posinset"; type_ = Int };

    (* Indicates the current "pressed" state of toggle buttons.
    * @see aria-checked @see aria-selected.
    *)
    Attribute { name = "aria-pressed"; jsx_name = "aria-pressed"; reason_jsx_name = "aria_pressed"; type_ = String (* Bool | 'false' | 'mixed' | 'true' *) };

    (* Indicates that the element is not editable, but is otherwise
    operable.
    * @see aria-disabled.
    *)
    Attribute { name = "aria-readonly"; jsx_name = "aria-readonly"; reason_jsx_name = "aria_readonly"; type_ = Booleanish_string };

    (* Indicates what notifications the user agent will trigger when the
    accessibility tree within a live region is modified.
    * @see aria-atomic.
    *)
    Attribute { name = "aria-relevant"; jsx_name = "aria-relevant"; reason_jsx_name = "aria_relevant"; type_ = String (* 'additions' | 'additions removals' | 'additions text' | 'all' | 'removals' | 'removals additions' | 'removals text' | 'text' | 'text additions' | 'text removals' *) };

    (* Indicates that user input is required on the element before a form may be
       submitted. *)
    Attribute { name = "aria-required"; jsx_name = "aria-required"; reason_jsx_name = "aria_required"; type_ = Booleanish_string };

    (* Defines a human-readable, author-localized description for the role of an element. *)
    Attribute { name = "aria-roledescription"; jsx_name = "aria-roledescription"; reason_jsx_name = "aria_roledescription"; type_ = String };

    (* Defines the total number of rows in a table, grid, or treegrid.
    * @see aria-rowindex.
    *)
    Attribute { name = "aria-rowcount"; jsx_name = "aria-rowcount"; reason_jsx_name = "aria_rowcount"; type_ = Int };

    (* Defines an element's row index or position with respect to the total number of rows within a table, grid, or
    treegrid.
    * @see aria-rowcount @see aria-rowspan.
    *)
    Attribute { name = "aria-rowindex"; jsx_name = "aria-rowindex"; reason_jsx_name = "aria_rowindex"; type_ = Int };

    (* *)

    Attribute { name = "aria-rowindextext"; jsx_name = "aria-rowindextext"; reason_jsx_name = "aria_rowindextext"; type_ = String };

    (* Defines the number of rows spanned by a cell or gridcell within a table, grid, or treegrid.
    * @see aria-rowindex @see aria-colspan.
    *)
    Attribute { name = "aria-rowspan"; jsx_name = "aria-rowspan"; reason_jsx_name = "aria_rowspan"; type_ = Int };

    (* Indicates the current "selected" state of various widgets.
    * @see aria-checked @see aria-pressed.
    *)
    Attribute { name = "aria-selected"; jsx_name = "aria-selected"; reason_jsx_name = "aria_selected"; type_ = Booleanish_string };

    (* Defines the number of items in the current set of listitems or treeitems.
    Not required if all elements in the set are present in the DOM.
    * @see aria-posinset.
    *)
    Attribute { name = "aria-setsize"; jsx_name = "aria-setsize"; reason_jsx_name = "aria_setsize"; type_ = Int };

    (* Indicates if items in a table or grid are sorted in ascending or
       descending order. *)
    Attribute { name = "aria-sort"; jsx_name = "aria-sort"; reason_jsx_name = "aria_sort"; type_ = String (* 'none' | 'ascending' | 'descending' | 'other' *) };

    (* Defines the maximum allowed value for a range widget. *)

    Attribute { name = "aria-valuemax"; jsx_name = "aria-valuemax"; reason_jsx_name = "aria_valuemax"; type_ = Float };

    (* Defines the minimum allowed value for a range widget. *)

    Attribute { name = "aria-valuemin"; jsx_name = "aria-valuemin"; reason_jsx_name = "aria_valuemin"; type_ = Float };

    (* Defines the current value for a range widget.
    * @see aria-valuetext.
    *)
    Attribute { name = "aria-valuenow"; jsx_name = "aria-valuenow"; reason_jsx_name = "aria_valuenow"; type_ = Float };

    (* Defines the human readable text alternative of aria-valuenow for a range
       widget. *)
    Attribute { name = "aria-valuetext"; jsx_name = "aria-valuetext"; reason_jsx_name = "aria_valuetext"; type_ = String };

  ]

(* All the WAI-ARIA 1.1 role attribute values from
   https://www.w3.org/TR/wai-aria-1.1/#role_definitions *)
let aria_role = String
(* | Alert | Alertdialog | Application | Article | Banner | Button | Cell |
   Checkbox | Columnheader | Combobox | Complementary | Contentinfo | Definition
   | Dialog | Directory | Document | Feed | Figure | Form | Grid | Gridcell |
   Group | Heading | Img | Link | List | Listbox | Listitem | Log | Main |
   Marquee | Math | Menu | Menubar | Menuitem | Menuitemcheckbox | Menuitemradio
   | Navigation | None | Note | Option | Presentation | Progressbar | Radio |
   Radiogroup | Region | Row | Rowgroup | Rowheader | Scrollbar | Search |
   Searchbox | Separator | Slider | Spinbutton | Status | Switch | Tab | Table |
   Tablist | Tabpanel | Term | Textbox | Timer | Toolbar | Tooltip | Tree |
   Treegrid | Treeitem | Custom of String *)

let react_attributes =
  [
    Attribute { name = "class"; jsx_name = "class_name"; reason_jsx_name = "class_name"; type_ = String };
    Attribute { name = "checked"; jsx_name = "default_checked"; reason_jsx_name = "default_checked"; type_ = Bool };
    Attribute { name = "value"; jsx_name = "default_value"; reason_jsx_name = "default_value"; type_ = String (* | number | ReadonlyArray<String> *) };
    (* https://reactjs.org/docs/dom-elements.html *)
    Attribute { name = "dangerouslySetInnerHTML"; jsx_name = "dangerously_set_inner_html"; reason_jsx_name = "dangerously_set_inner_html"; type_ = Inner_html };
    Attribute { name = "ref"; jsx_name = "ref"; reason_jsx_name = "ref"; type_ = Ref };
    Attribute { name = "key"; jsx_name = "key"; reason_jsx_name = "key"; type_ = String };
    Attribute { name = "suppressContentEditableWarning"; jsx_name = "suppress_content_editable_warning"; reason_jsx_name = "suppress_content_editable_warning"; type_ = Bool };
    Attribute { name = "suppressHydrationWarning"; jsx_name = "suppress_hydration_warning"; reason_jsx_name = "suppress_hydration_warning"; type_ = Bool };
  ]

let global_attributes =
  [
    (* https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes *)
    (* Standard HTML Attributes *)
    Attribute { name = "accesskey"; jsx_name = "access_key"; reason_jsx_name = "access_key"; type_ = String };
    Attribute { name = "autocapitalize"; jsx_name = "auto_capitalize"; reason_jsx_name = "auto_capitalize"; type_ = String };
    Attribute { name = "autofocus"; jsx_name = "auto_focus"; reason_jsx_name = "auto_focus"; type_ = Bool };
    Attribute { name = "contextmenu"; jsx_name = "context_menu"; reason_jsx_name = "context_menu"; type_ = String };
    Attribute { name = "contenteditable"; jsx_name = "content_editable"; reason_jsx_name = "content_editable"; type_ = Booleanish_string };
    Attribute { name = "dir"; jsx_name = "dir"; reason_jsx_name = "dir"; type_ = String };
    Attribute { name = "draggable"; jsx_name = "draggable"; reason_jsx_name = "draggable"; type_ = Booleanish_string };
    Attribute { name = "hidden"; jsx_name = "hidden"; reason_jsx_name = "hidden"; type_ = Bool };
    Attribute { name = "id"; jsx_name = "id"; reason_jsx_name = "id"; type_ = String };
    Attribute { name = "itemprop"; jsx_name = "item_prop"; reason_jsx_name = "item_prop"; type_ = String };
    Attribute { name = "itemscope"; jsx_name = "item_scope"; reason_jsx_name = "item_scope"; type_ = Bool };
    Attribute { name = "itemtype"; jsx_name = "item_type"; reason_jsx_name = "item_type"; type_ = String };
    Attribute { name = "itemid"; jsx_name = "item_id"; reason_jsx_name = "item_id"; type_ = String };
    Attribute { name = "itemref"; jsx_name = "item_ref"; reason_jsx_name = "item_ref"; type_ = String };
    Attribute { name = "lang"; jsx_name = "lang"; reason_jsx_name = "lang"; type_ = String };
    Attribute { name = "placeholder"; jsx_name = "placeholder"; reason_jsx_name = "placeholder"; type_ = String };
    Attribute { name = "part"; jsx_name = "part"; reason_jsx_name = "part"; type_ = String };
    Attribute { name = "nonce"; jsx_name = "nonce"; reason_jsx_name = "nonce"; type_ = String };
    Attribute { name = "slot"; jsx_name = "slot"; reason_jsx_name = "slot"; type_ = String };
    Attribute { name = "spellcheck"; jsx_name = "spell_check"; reason_jsx_name = "spell_check"; type_ = Booleanish_string };
    Attribute { name = "style"; jsx_name = "style"; reason_jsx_name = "style"; type_ = Style };
    Attribute { name = "tabindex"; jsx_name = "tab_index"; reason_jsx_name = "tab_index"; type_ = Int };
    Attribute { name = "enterkeyhint"; jsx_name = "enter_key_hint"; reason_jsx_name = "enter_key_hint"; type_ = Int };
    (* data-* attributes are globaly available *)
    (* Experimental ; Attribute {name= "exportParts"; jsx_name= "exportParts";
       type_= Int} *)
    Attribute { name = "title"; jsx_name = "title"; reason_jsx_name = "title"; type_ = String };
    Attribute { name = "translate"; jsx_name = "translate"; reason_jsx_name = "translate"; type_ = String (* 'yes' | 'no' *) };

    (* Living Standard * Hints at the type of data that might be entered by the
       user while editing the element or its contents * @see
       https://html.spec.whatwg.org/multipage/interaction.html#input-modalities:-the-inputmode-attribute *)
    Attribute { name = "inputmode"; jsx_name = "input_mode"; reason_jsx_name = "input_mode"; type_ = String (* 'none' | 'text' | 'tel' | 'url' | 'email' | 'numeric' | 'decimal' | 'search' *) };

    (* Specify that a standard HTML element should behave like a defined custom
       built-in element * @see
       https://html.spec.whatwg.org/multipage/custom-elements.html#attr-is *)
    Attribute { name = "is"; jsx_name = "is"; reason_jsx_name = "is"; type_ = String };
  ]

let element_attributes =
  [
    (* Attribute { name = "radioGroup"; jsx_name = "radio_group"; reason_jsx_name = "radio_group"; type_ = String }; Does it exist? *)

    (* WAI-ARIA *)
    Attribute { name = "role"; jsx_name = "role"; reason_jsx_name = "role"; type_ = aria_role };

    (* RDFa Attributes *)
    Attribute { name = "about"; jsx_name = "about"; reason_jsx_name = "about"; type_ = String };
    (* Attribute { name = "dataType"; jsx_name = "data_type"; reason_jsx_name = "data_type"; type_ = String }; *)
    Attribute { name = "inlist"; jsx_name = "inlist"; reason_jsx_name = "inlist"; type_ = String (* any *) };
    Attribute { name = "prefix"; jsx_name = "prefix"; reason_jsx_name = "prefix"; type_ = String };
    Attribute { name = "property"; jsx_name = "property"; reason_jsx_name = "property"; type_ = String };
    Attribute { name = "resource"; jsx_name = "resource"; reason_jsx_name = "resource"; type_ = String };
    Attribute { name = "typeof"; jsx_name = "typeof"; reason_jsx_name = "typeof"; type_ = String };
    Attribute { name = "vocab"; jsx_name = "vocab"; reason_jsx_name = "vocab"; type_ = String };

    (* Non-standard Attributes *)
    (* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/Input#autocorrect *)
    Attribute { name = "autocorrect"; jsx_name = "auto_correct"; reason_jsx_name = "auto_correct"; type_ = String };
    (* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/Input#attr-autosave *)
    Attribute { name = "autosave"; jsx_name = "auto_save"; reason_jsx_name = "auto_save"; type_ = String };
    Attribute { name = "color"; jsx_name = "color"; reason_jsx_name = "color"; type_ = String };
    Attribute { name = "results"; jsx_name = "results"; reason_jsx_name = "results"; type_ = Int };
    Attribute { name = "security"; jsx_name = "security"; reason_jsx_name = "security"; type_ = String };
  ]

let anchor_html_attributes =
  [
    Attribute { name = "download"; jsx_name = "download"; reason_jsx_name = "download"; type_ = String (* any *) };
    Attribute { name = "href"; jsx_name = "href"; reason_jsx_name = "href"; type_ = String };
    Attribute { name = "hrefLang"; jsx_name = "href_lang"; reason_jsx_name = "href_lang"; type_ = String };
    Attribute { name = "media"; jsx_name = "media"; reason_jsx_name = "media"; type_ = String };
    Attribute { name = "ping"; jsx_name = "ping"; reason_jsx_name = "ping"; type_ = String };
    Attribute { name = "rel"; jsx_name = "rel"; reason_jsx_name = "rel"; type_ = String };
    Attribute { name = "target"; jsx_name = "target"; reason_jsx_name = "target"; type_ = attribute_anchor_target };
    Attribute { name = "type"; jsx_name = "type"; reason_jsx_name = "type_"; type_ = String };
    Attribute { name = "referrerpolicy"; jsx_name = "referrer_policy"; reason_jsx_name = "referrer_policy"; type_ = attribute_referrer_policy };
  ]

let area_html_attributes =
  [
    Attribute { name = "alt"; jsx_name = "alt"; reason_jsx_name = "alt"; type_ = String };
    Attribute { name = "coords"; jsx_name = "coords"; reason_jsx_name = "coords"; type_ = String };
    Attribute { name = "download"; jsx_name = "download"; reason_jsx_name = "download"; type_ = String (* any *) };
    Attribute { name = "href"; jsx_name = "href"; reason_jsx_name = "href"; type_ = String };
    Attribute { name = "hreflang"; jsx_name = "href_lang"; reason_jsx_name = "href_lang"; type_ = String };
    Attribute { name = "media"; jsx_name = "media"; reason_jsx_name = "media"; type_ = String };
    Attribute { name = "referrerpolicy"; jsx_name = "referrer_policy"; reason_jsx_name = "referrer_policy"; type_ = attribute_referrer_policy };
    Attribute { name = "rel"; jsx_name = "rel"; reason_jsx_name = "rel"; type_ = String };
    Attribute { name = "shape"; jsx_name = "shape"; reason_jsx_name = "shape"; type_ = String };
    Attribute { name = "target"; jsx_name = "target"; reason_jsx_name = "target"; type_ = String };
  ]

let base_html_attributes =
  [
    Attribute { name = "href"; jsx_name = "href"; reason_jsx_name = "href"; type_ = String };
    Attribute { name = "target"; jsx_name = "target"; reason_jsx_name = "target"; type_ = String };
  ]

let blockquote_html_attributes =
  [
    Attribute { name = "cite"; jsx_name = "cite"; reason_jsx_name = "cite"; type_ = String };
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/button *)
let button_html_attributes =
  [
    Attribute { name = "autofocus"; jsx_name = "auto_focus"; reason_jsx_name = "auto_focus"; type_ = Bool };
    Attribute { name = "autocomplete"; jsx_name = "auto_complete"; reason_jsx_name = "auto_complete"; type_ = String };
    Attribute { name = "disabled"; jsx_name = "disabled"; reason_jsx_name = "disabled"; type_ = Bool };
    Attribute { name = "form"; jsx_name = "form"; reason_jsx_name = "form"; type_ = String };
    Attribute { name = "formaction"; jsx_name = "form_action"; reason_jsx_name = "form_action"; type_ = String };
    Attribute { name = "formenctype"; jsx_name = "form_enc_type"; reason_jsx_name = "form_enc_type"; type_ = String };
    (* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/form#method *)
    Attribute { name = "formmethod"; jsx_name = "form_method"; reason_jsx_name = "form_method"; type_ = String };
    Attribute { name = "formnovalidate"; jsx_name = "form_no_validate"; reason_jsx_name = "form_no_validate"; type_ = Bool };
    Attribute { name = "formtarget"; jsx_name = "form_target"; reason_jsx_name = "form_target"; type_ = String };
    Attribute { name = "name"; jsx_name = "name"; reason_jsx_name = "name"; type_ = String };
    Attribute { name = "popovertarget"; jsx_name = "popover_target"; reason_jsx_name = "popover_target"; type_ = String };
    Attribute { name = "popovertargetaction"; jsx_name = "popover_target_action"; reason_jsx_name = "popover_target_action"; type_ = String };
    Attribute { name = "type"; jsx_name = "type"; reason_jsx_name = "type_"; type_ = String (* 'submit' | 'reset' | 'button' *) };
    Attribute { name = "value"; jsx_name = "value"; reason_jsx_name = "value"; type_ = String (* | ReadonlyArray<String> | number *) };
  ]

let canvas_html_attributes =
  [
    Attribute { name = "height"; jsx_name = "height"; reason_jsx_name = "height"; type_ = String (* number | *) };
    Attribute { name = "width"; jsx_name = "width"; reason_jsx_name = "width"; type_ = String (* number | *) }
  ]

let col_html_attributes =
  [
    Attribute { name = "span"; jsx_name = "span"; reason_jsx_name = "span"; type_ = Int (* number *) };
    Attribute { name = "width"; jsx_name = "width"; reason_jsx_name = "width"; type_ = String (* number | *) }
  ]

let colgroup_html_attributes =
  [
    Attribute { name = "span"; jsx_name = "span"; reason_jsx_name = "span"; type_ = Int (* number *) }
  ]

let data_html_attributes =
  [
    Attribute { name = "value"; jsx_name = "value"; reason_jsx_name = "value"; type_ = String (* | ReadonlyArray<String> | number *) }
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/details *)
let details_html_attributes =
  [
    Attribute { name = "open"; jsx_name = "open"; reason_jsx_name = "open_"; type_ = Bool }; Event { jsx_name = "on_toggle"; type_ = Media }
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/del *)
let del_html_attributes =
  [
    Attribute { name = "cite"; type_ = String; jsx_name = "cite"; reason_jsx_name = "cite" };
    Attribute { name = "datetime"; type_ = String; jsx_name = "date_time"; reason_jsx_name = "date_time" };
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/dialog *)
let dialog_html_attributes =
  [
    Attribute { name = "open"; jsx_name = "open"; reason_jsx_name = "open_"; type_ = Bool }
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/embed *)
let embed_html_attributes =
  [
    Attribute { name = "height"; jsx_name = "height"; reason_jsx_name = "height"; type_ = String (* number | *); };
    Attribute { name = "src"; jsx_name = "src"; reason_jsx_name = "src"; type_ = String; };
    Attribute { name = "type"; jsx_name = "type"; reason_jsx_name = "type_"; type_ = String; };
    Attribute { name = "width"; jsx_name = "width"; reason_jsx_name = "width"; type_ = String; (* number | *) };
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/fieldset *)
let fieldset_html_attributes =
  [
    Attribute { name = "disabled"; jsx_name = "disabled"; reason_jsx_name = "disabled"; type_ = Bool };
    Attribute { name = "form"; jsx_name = "form"; reason_jsx_name = "form"; type_ = String };
    Attribute { name = "name"; jsx_name = "name"; reason_jsx_name = "name"; type_ = String };
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/form *)
let form_html_attributes =
  [
    Attribute { name = "accept"; jsx_name = "accept"; reason_jsx_name = "accept"; type_ = String };
    Attribute { name = "accept-charset"; jsx_name = "accept_charset"; reason_jsx_name = "accept_charset"; type_ = String };
    Attribute { name = "autocapitalize"; jsx_name = "auto_capitalize"; reason_jsx_name = "auto_capitalize"; type_ = String };
    Attribute { name = "autocomplete"; jsx_name = "auto_complete"; reason_jsx_name = "auto_complete"; type_ = String };
    Attribute { name = "name"; jsx_name = "name"; reason_jsx_name = "name"; type_ = String };
    Attribute { name = "rel"; jsx_name = "rel"; reason_jsx_name = "rel"; type_ = String };
    Attribute { name = "enctype"; jsx_name = "enc_type"; reason_jsx_name = "enc_type"; type_ = String };
    Attribute { name = "action"; jsx_name = "action"; reason_jsx_name = "action"; type_ = String };
    Attribute { name = "method"; jsx_name = "method"; reason_jsx_name = "method_"; type_ = String };
    Attribute { name = "novalidate"; jsx_name = "no_validate"; reason_jsx_name = "no_validate"; type_ = Bool };
    Attribute { name = "target"; jsx_name = "target"; reason_jsx_name = "target"; type_ = String };
  ]

let html_html_attributes =
  [
    Attribute { name = "manifest"; jsx_name = "manifest"; reason_jsx_name = "manifest"; type_ = String };
  ]

let iframe_html_attributes =
  [
    Attribute { name = "allow"; jsx_name = "allow"; reason_jsx_name = "allow"; type_ = String };
    Attribute { name = "allowfullscreen"; jsx_name = "allow_full_screen"; reason_jsx_name = "allow_full_screen"; type_ = Bool };
    Attribute { name = "allowtransparency"; jsx_name = "allow_transparency"; reason_jsx_name = "allow_transparency"; type_ = Bool };
    Attribute { name = "csp"; jsx_name = "csp"; reason_jsx_name = "csp"; type_ = String };
    Attribute { name = "credentialless"; jsx_name = "credential_less"; reason_jsx_name = "credential_less"; type_ = String };
    Attribute { name = "loading"; jsx_name = "loading"; reason_jsx_name = "loading"; type_ = String };
    Attribute { name = "sandbox"; jsx_name = "sandbox"; reason_jsx_name = "sandbox"; type_ = String };
    Attribute { name = "name"; jsx_name = "name"; reason_jsx_name = "name"; type_ = String };
    Attribute { name = "sandbox"; jsx_name = "sandbox"; reason_jsx_name = "sandbox"; type_ = String };
    Attribute { name = "seamless"; jsx_name = "seamless"; reason_jsx_name = "seamless"; type_ = Bool };
    Attribute { name = "src"; jsx_name = "src"; reason_jsx_name = "src"; type_ = String };
    Attribute { name = "srcdoc"; jsx_name = "src_doc"; reason_jsx_name = "src_doc"; type_ = String };
    Attribute { name = "width"; jsx_name = "width"; reason_jsx_name = "width"; type_ = String (* number | *) };
    Attribute { name = "height"; jsx_name = "height"; reason_jsx_name = "height"; type_ = String (* number | *) };
    (* Deprecated attributes *)
    Attribute { name = "align"; jsx_name = "align"; reason_jsx_name = "align"; type_ = String };
    Attribute { name = "longdesc"; jsx_name = "long_desc"; reason_jsx_name = "long_desc"; type_ = String };
    Attribute { name = "frameborder"; jsx_name = "frame_border"; reason_jsx_name = "frame_border"; type_ = String (* number | *) };
    Attribute { name = "marginheight"; jsx_name = "margin_height"; reason_jsx_name = "margin_height"; type_ = Int (* number *) };
    Attribute { name = "marginwidth"; jsx_name = "margin_width"; reason_jsx_name = "margin_width"; type_ = Int (* number *) };
    Attribute { name = "scrolling"; jsx_name = "scrolling"; reason_jsx_name = "scrolling"; type_ = String };
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/img *)
let img_html_attributes =
  [
    Attribute { name = "alt"; jsx_name = "alt"; reason_jsx_name = "alt"; type_ = String };
    Attribute { name = "crossorigin"; jsx_name = "cross_origin"; reason_jsx_name = "cross_origin"; type_ = String (* "anonymous" | "use-credentials" | "" *) };
    Attribute { name = "elementtiming"; jsx_name = "element_timing"; reason_jsx_name = "element_timing"; type_ = String };
    Attribute { name = "fetchpriority"; jsx_name = "fetch_priority"; reason_jsx_name = "fetch_priority"; type_ = String };
    Attribute { name = "loading"; jsx_name = "loading"; reason_jsx_name = "loading"; type_ = String };
    Attribute { name = "ismap"; jsx_name = "is_map"; reason_jsx_name = "is_map"; type_ = Bool };
    Attribute { name = "decoding"; jsx_name = "decoding"; reason_jsx_name = "decoding"; type_ = String (* "async" | "auto" | "sync" *) };
    Attribute { name = "sizes"; jsx_name = "sizes"; reason_jsx_name = "sizes"; type_ = String };
    Attribute { name = "src"; jsx_name = "src"; reason_jsx_name = "src"; type_ = String };
    Attribute { name = "srcset"; jsx_name = "srcset"; reason_jsx_name = "srcset"; type_ = String };
    Attribute { name = "usemap"; jsx_name = "usemap"; reason_jsx_name = "usemap"; type_ = String };
    Attribute { name = "width"; jsx_name = "width"; reason_jsx_name = "width"; type_ = String (* number | *) };
    Attribute { name = "height"; jsx_name = "height"; reason_jsx_name = "height"; type_ = String (* number | *) };
    (* Deprecated *)
    (* align, border, hspace, longdesc, name, vspace *)
  ]

let ins_html_attributes =
  [
    Attribute { name = "cite"; jsx_name = "cite"; reason_jsx_name = "cite"; type_ = String };
    Attribute { name = "datetime"; jsx_name = "datetime"; reason_jsx_name = "datetime"; type_ = String };
  ]

let input_type_attribute = String
(* | 'button' | 'checkbox' | 'color' | 'date' | 'datetime-local' | 'email' |
   'file' | 'hidden' | 'image' | 'month' | 'number' | 'password' | 'radio' |
   'range' | 'reset' | 'search' | 'submit' | 'tel' | 'text' | 'time' | 'url' |
   'week' | (String @ {}); *)

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input *)
let input_html_attributes =
  [
    Attribute { name = "accept"; jsx_name = "accept"; reason_jsx_name = "accept"; type_ = String };
    Attribute { name = "alt"; jsx_name = "alt"; reason_jsx_name = "alt"; type_ = String };
    Attribute { name = "autocomplete"; jsx_name = "auto_complete"; reason_jsx_name = "auto_complete"; type_ = String };
    Attribute { name = "autofocus"; jsx_name = "auto_focus"; reason_jsx_name = "auto_focus"; type_ = Bool };
    Attribute { name = "capture"; jsx_name = "capture"; reason_jsx_name = "capture"; type_ = String (* Bool | *) (* https://www.w3.org/TR/html-media-capture/ *) };
    Attribute { name = "checked"; jsx_name = "checked"; reason_jsx_name = "checked"; type_ = Bool };
    Attribute { name = "crossorigin"; jsx_name = "cross_origin"; reason_jsx_name = "cross_origin"; type_ = String };
    Attribute { name = "dirname"; jsx_name = "dirname"; reason_jsx_name = "dirname"; type_ = String };
    Attribute { name = "disabled"; jsx_name = "disabled"; reason_jsx_name = "disabled"; type_ = Bool };
    Attribute { name = "form"; jsx_name = "form"; reason_jsx_name = "form"; type_ = String };
    Attribute { name = "formaction"; jsx_name = "form_action"; reason_jsx_name = "form_action"; type_ = String };
    Attribute { name = "formenctype"; jsx_name = "form_enc_type"; reason_jsx_name = "form_enc_type"; type_ = String };
    Attribute { name = "method"; jsx_name = "form_method"; reason_jsx_name = "form_method"; type_ = String };
    Attribute { name = "novalidate"; jsx_name = "form_no_validate"; reason_jsx_name = "form_no_validate"; type_ = Bool };
    Attribute { name = "target"; jsx_name = "form_target"; reason_jsx_name = "form_target"; type_ = String };
    Attribute { name = "height"; jsx_name = "height"; reason_jsx_name = "height"; type_ = String (* number | *) };
    Attribute { name = "list"; jsx_name = "list"; reason_jsx_name = "list"; type_ = String };
    Attribute { name = "max"; jsx_name = "max"; reason_jsx_name = "max"; type_ = String (* number | *) };
    Attribute { name = "maxlength"; jsx_name = "max_length"; reason_jsx_name = "max_length"; type_ = Int (* number *) };
    Attribute { name = "min"; jsx_name = "min"; reason_jsx_name = "min"; type_ = String (* number | *) };
    Attribute { name = "minlength"; jsx_name = "min_length"; reason_jsx_name = "min_length"; type_ = Int (* number *) };
    Attribute { name = "multiple"; jsx_name = "multiple"; reason_jsx_name = "multiple"; type_ = Bool };
    Attribute { name = "name"; jsx_name = "name"; reason_jsx_name = "name"; type_ = String };
    Attribute { name = "pattern"; jsx_name = "pattern"; reason_jsx_name = "pattern"; type_ = String };
    Attribute { name = "placeholder"; jsx_name = "placeholder"; reason_jsx_name = "placeholder"; type_ = String };
    Attribute { name = "readonly"; jsx_name = "read_only"; reason_jsx_name = "read_only"; type_ = Bool };
    Attribute { name = "required"; jsx_name = "required"; reason_jsx_name = "required"; type_ = Bool };
    Attribute { name = "size"; jsx_name = "size"; reason_jsx_name = "size"; type_ = Int (* number *) };
    Attribute { name = "src"; jsx_name = "src"; reason_jsx_name = "src"; type_ = String };
    Attribute { name = "step"; jsx_name = "step"; reason_jsx_name = "step"; type_ = String (* number | *) };
    Attribute { name = "type"; jsx_name = "type"; reason_jsx_name = "type_"; type_ = input_type_attribute };
    Attribute { name = "value"; jsx_name = "value"; reason_jsx_name = "value"; type_ = String (* | ReadonlyArray<String> | number *) };
    Attribute { name = "width"; jsx_name = "width"; reason_jsx_name = "width"; type_ = String (* number | *) };
    (* Added by React, oninput is the HTML *)
    Event { jsx_name = "on_change"; type_ = Form };
  ]

let keygen_html_attributes =
  [
    Attribute { name = "autofocus"; jsx_name = "auto_focus"; reason_jsx_name = "auto_focus"; type_ = Bool };
    Attribute { name = "challenge"; jsx_name = "challenge"; reason_jsx_name = "challenge"; type_ = String };
    Attribute { name = "disabled"; jsx_name = "disabled"; reason_jsx_name = "disabled"; type_ = Bool };
    Attribute { name = "form"; jsx_name = "form"; reason_jsx_name = "form"; type_ = String };
    Attribute { name = "keytype"; jsx_name = "key_type"; reason_jsx_name = "key_type"; type_ = String };
    Attribute { name = "keyparams"; jsx_name = "key_params"; reason_jsx_name = "key_params"; type_ = String };
    Attribute { name = "name"; jsx_name = "name"; reason_jsx_name = "name"; type_ = String };
  ]

let label_html_attributes =
  [
    Attribute { name = "form"; jsx_name = "form"; reason_jsx_name = "form"; type_ = String };
    Attribute { name = "for"; jsx_name = "html_for"; reason_jsx_name = "html_for"; type_ = String };
  ]

let li_html_attributes =
  [
    Attribute { name = "value"; jsx_name = "value"; reason_jsx_name = "value"; type_ = String (* | ReadonlyArray<String> | number *) }
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/link *)
let link_html_attributes =
  [
    Attribute { name = "as"; jsx_name = "as"; reason_jsx_name = "as_"; type_ = String };
    Attribute { name = "crossorigin"; jsx_name = "cross_origin"; reason_jsx_name = "cross_origin"; type_ = String };
    Attribute { name = "blocking"; jsx_name = "blocking"; reason_jsx_name = "blocking"; type_ = Bool }; (* Experimental *)
    Attribute { name = "disabled"; jsx_name = "disabled"; reason_jsx_name = "disabled"; type_ = Bool }; (* Deprecated *)
    Attribute { name = "fetchpriority"; jsx_name = "fetch_priority"; reason_jsx_name = "fetch_priority"; type_ = String }; (* Experimental *)
    Attribute { name = "referrerpolicy"; jsx_name = "referrer_policy"; reason_jsx_name = "referrer_policy"; type_ = attribute_referrer_policy };
    Attribute { name = "href"; jsx_name = "href"; reason_jsx_name = "href"; type_ = String };
    Attribute { name = "hreflang"; jsx_name = "href_lang"; reason_jsx_name = "href_lang"; type_ = String };
    Attribute { name = "integrity"; jsx_name = "integrity"; reason_jsx_name = "integrity"; type_ = String };
    Attribute { name = "imagesizes"; jsx_name = "image_sizes"; reason_jsx_name = "image_sizes"; type_ = String };
    Attribute { name = "imagesrcset"; jsx_name = "image_src_set"; reason_jsx_name = "image_src_set"; type_ = String };
    Attribute { name = "media"; jsx_name = "media"; reason_jsx_name = "media"; type_ = String };
    Attribute { name = "rel"; jsx_name = "rel"; reason_jsx_name = "rel"; type_ = String };
    Attribute { name = "title"; jsx_name = "title"; reason_jsx_name = "title"; type_ = String };
    Attribute { name = "sizes"; jsx_name = "sizes"; reason_jsx_name = "sizes"; type_ = String };
    Attribute { name = "type"; jsx_name = "type"; reason_jsx_name = "type_"; type_ = String };
    Attribute { name = "charset"; jsx_name = "char_set"; reason_jsx_name = "char_set"; type_ = String }; (* non standard *)
  ]

let map_html_attributes =
  [
    Attribute { name = "name"; jsx_name = "name"; reason_jsx_name = "name"; type_ = String };
  ]

let menu_html_attributes =
  [
    Attribute { name = "type"; jsx_name = "type"; reason_jsx_name = "type_"; type_ = String };
  ]

(* isn't validated with mdn *)
let media_html_attributes =
  [
    Attribute { name = "autoplay"; jsx_name = "auto_play"; reason_jsx_name = "auto_play"; type_ = Bool };
    Attribute { name = "controls"; jsx_name = "controls"; reason_jsx_name = "controls"; type_ = Bool };
    Attribute { name = "controlslist"; jsx_name = "controls_list"; reason_jsx_name = "controls_list"; type_ = String };
    Attribute { name = "crossorigin"; jsx_name = "cross_origin"; reason_jsx_name = "cross_origin"; type_ = String };
    Attribute { name = "loop"; jsx_name = "loop"; reason_jsx_name = "loop"; type_ = Bool };
    (* deprecated *)
    Attribute { name = "mediagroup"; jsx_name = "media_group"; reason_jsx_name = "media_group"; type_ = String };
    Attribute { name = "muted"; jsx_name = "muted"; reason_jsx_name = "muted"; type_ = Bool };
    Attribute { name = "playsinline"; jsx_name = "plays_inline"; reason_jsx_name = "plays_inline"; type_ = Bool };
    Attribute { name = "preload"; jsx_name = "preload"; reason_jsx_name = "preload"; type_ = String };
    Attribute { name = "src"; jsx_name = "src"; reason_jsx_name = "src"; type_ = String };
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/meta *)
let meta_html_attributes =
  [
    Attribute { name = "charset"; jsx_name = "char_set"; reason_jsx_name = "char_set"; type_ = String };
    Attribute { name = "content"; jsx_name = "content"; reason_jsx_name = "content"; type_ = String };
    Attribute { name = "http-equiv"; jsx_name = "http_equiv"; reason_jsx_name = "http_equiv"; type_ = String };
    Attribute { name = "name"; jsx_name = "name"; reason_jsx_name = "name"; type_ = String };
    Attribute { name = "media"; jsx_name = "media"; reason_jsx_name = "media"; type_ = String };
  ]

let meter_html_attributes =
  [
    Attribute { name = "form"; jsx_name = "form"; reason_jsx_name = "form"; type_ = String };
    Attribute { name = "high"; jsx_name = "high"; reason_jsx_name = "high"; type_ = Int (* number *) };
    Attribute { name = "low"; jsx_name = "low"; reason_jsx_name = "low"; type_ = Int (* number *) };
    Attribute { name = "max"; jsx_name = "max"; reason_jsx_name = "max"; type_ = String (* number | *) };
    Attribute { name = "min"; jsx_name = "min"; reason_jsx_name = "min"; type_ = String (* number | *) };
    Attribute { name = "optimum"; jsx_name = "optimum"; reason_jsx_name = "optimum"; type_ = Int (* number *) };
    Attribute { name = "value"; jsx_name = "value"; reason_jsx_name = "value"; type_ = String (* | ReadonlyArray<String> | number *) };
  ]

let quote_html_attributes =
  [
    Attribute { name = "cite"; jsx_name = "cite"; reason_jsx_name = "cite"; type_ = String };
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/object *)
(* TODO: lacks a few *)
let object_html_attributes =
  [
    Attribute { name = "classid"; jsx_name = "class_id"; reason_jsx_name = "class_id"; type_ = String };
    Attribute { name = "data"; jsx_name = "data"; reason_jsx_name = "data"; type_ = String };
    Attribute { name = "form"; jsx_name = "form"; reason_jsx_name = "form"; type_ = String };
    Attribute { name = "height"; jsx_name = "height"; reason_jsx_name = "height"; type_ = String (* number | *) };
    Attribute { name = "name"; jsx_name = "name"; reason_jsx_name = "name"; type_ = String };
    Attribute { name = "type"; jsx_name = "type"; reason_jsx_name = "type_"; type_ = String };
    Attribute { name = "usemap"; jsx_name = "use_map"; reason_jsx_name = "use_map"; type_ = String };
    Attribute { name = "width"; jsx_name = "width"; reason_jsx_name = "width"; type_ = String (* number | *) };
    Attribute { name = "wmode"; jsx_name = "wmode"; reason_jsx_name = "wmode"; type_ = String };
  ]

let ol_html_attributes =
  [
    Attribute { name = "reversed"; jsx_name = "reversed"; reason_jsx_name = "reversed"; type_ = Bool };
    Attribute { name = "start"; jsx_name = "start"; reason_jsx_name = "start"; type_ = Int (* number *) };
    Attribute { name = "type"; jsx_name = "type"; reason_jsx_name = "type_"; type_ = String (* '1' | 'a' | 'A' | 'i' | 'I' *) };
  ]

let optgroup_html_attributes =
  [
    Attribute { name = "disabled"; jsx_name = "disabled"; reason_jsx_name = "disabled"; type_ = Bool };
    Attribute { name = "label"; jsx_name = "label"; reason_jsx_name = "label"; type_ = String };
  ]

let option_html_attributes =
  [
    Attribute { name = "disabled"; jsx_name = "disabled"; reason_jsx_name = "disabled"; type_ = Bool };
    Attribute { name = "label"; jsx_name = "label"; reason_jsx_name = "label"; type_ = String };
    Attribute { name = "selected"; jsx_name = "selected"; reason_jsx_name = "selected"; type_ = Bool };
    Attribute { name = "value"; jsx_name = "value"; reason_jsx_name = "value"; type_ = String (* | ReadonlyArray<String> | number *) };
  ]

let output_html_attributes =
  [
    Attribute { name = "form"; jsx_name = "form"; reason_jsx_name = "form"; type_ = String };
    Attribute { name = "for"; jsx_name = "html_for"; reason_jsx_name = "html_for"; type_ = String };
    Attribute { name = "name"; jsx_name = "name"; reason_jsx_name = "name"; type_ = String };
  ]

let param_html_attributes =
  [
    Attribute { name = "name"; jsx_name = "name"; reason_jsx_name = "name"; type_ = String };
    Attribute { name = "value"; jsx_name = "value"; reason_jsx_name = "value"; type_ = String (* | ReadonlyArray<String> | number *) };
  ]

let progress_html_attributes =
  [
    Attribute { name = "max"; jsx_name = "max"; reason_jsx_name = "max"; type_ = String (* number | *) };
    Attribute { name = "value"; jsx_name = "value"; reason_jsx_name = "value"; type_ = String (* | ReadonlyArray<String> | number *) };
  ]

let slot_html_attributes =
  [
    Attribute { name = "name"; jsx_name = "name"; reason_jsx_name = "name"; type_ = String };
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/script *)
let script_html_attributes =
  [
    Attribute { name = "async"; jsx_name = "async"; reason_jsx_name = "async"; type_ = Bool };
    Attribute { name = "charset"; jsx_name = "char_set"; reason_jsx_name = "char_set"; type_ = String };
    Attribute { name = "crossorigin"; jsx_name = "cross_origin"; reason_jsx_name = "cross_origin"; type_ = String };
    Attribute { name = "defer"; jsx_name = "defer"; reason_jsx_name = "defer"; type_ = Bool };
    Attribute { name = "integrity"; jsx_name = "integrity"; reason_jsx_name = "integrity"; type_ = String };
    Attribute { name = "nomodule"; jsx_name = "no_module"; reason_jsx_name = "no_module"; type_ = Bool };
    Attribute { name = "nonce"; jsx_name = "nonce"; reason_jsx_name = "nonce"; type_ = String };
    Attribute { name = "src"; jsx_name = "src"; reason_jsx_name = "src"; type_ = String };
    Attribute { name = "type"; jsx_name = "type"; reason_jsx_name = "type_"; type_ = String };
  ]

let select_html_attributes =
  [
    Attribute { name = "autocomplete"; jsx_name = "auto_complete"; reason_jsx_name = "auto_complete"; type_ = String };
    Attribute { name = "autofocus"; jsx_name = "auto_focus"; reason_jsx_name = "auto_focus"; type_ = Bool };
    Attribute { name = "disabled"; jsx_name = "disabled"; reason_jsx_name = "disabled"; type_ = Bool };
    Attribute { name = "form"; jsx_name = "form"; reason_jsx_name = "form"; type_ = String };
    Attribute { name = "multiple"; jsx_name = "multiple"; reason_jsx_name = "multiple"; type_ = Bool };
    Attribute { name = "name"; jsx_name = "name"; reason_jsx_name = "name"; type_ = String };
    Attribute { name = "required"; jsx_name = "required"; reason_jsx_name = "required"; type_ = Bool };
    Attribute { name = "size"; jsx_name = "size"; reason_jsx_name = "size"; type_ = Int (* number *) };
    Attribute { name = "value"; jsx_name = "value"; reason_jsx_name = "value"; type_ = String (* | ReadonlyArray<String> | number *) };
    Event { jsx_name = "on_change"; type_ = Form };
  ]

let source_html_attributes =
  [
    Attribute { name = "height"; jsx_name = "height"; reason_jsx_name = "height"; type_ = String (* number | *) };
    Attribute { name = "media"; jsx_name = "media"; reason_jsx_name = "media"; type_ = String };
    Attribute { name = "sizes"; jsx_name = "sizes"; reason_jsx_name = "sizes"; type_ = String };
    Attribute { name = "src"; jsx_name = "src"; reason_jsx_name = "src"; type_ = String };
    Attribute { name = "srcset"; jsx_name = "src_set"; reason_jsx_name = "src_set"; type_ = String };
    Attribute { name = "type"; jsx_name = "type"; reason_jsx_name = "type_"; type_ = String };
    Attribute { name = "width"; jsx_name = "width"; reason_jsx_name = "width"; type_ = String (* number | *) };
  ]

let style_html_attributes =
  [
    Attribute { name = "media"; jsx_name = "media"; reason_jsx_name = "media"; type_ = String };
    Attribute { name = "nonce"; jsx_name = "nonce"; reason_jsx_name = "nonce"; type_ = String };
    Attribute { name = "scoped"; jsx_name = "scoped"; reason_jsx_name = "scoped"; type_ = Bool };
    Attribute { name = "type"; jsx_name = "type"; reason_jsx_name = "type_"; type_ = String }
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/table *)
(* All attributes are deprecated *)
let table_html_attributes =
  [
    Attribute { name = "cellpadding"; jsx_name = "cell_padding"; reason_jsx_name = "cell_padding"; type_ = String (* number | *) };
    Attribute { name = "cellspacing"; jsx_name = "cell_spacing"; reason_jsx_name = "cell_spacing"; type_ = String (* number | *) };
    Attribute { name = "summary"; jsx_name = "summary"; reason_jsx_name = "summary"; type_ = String };
    Attribute { name = "width"; jsx_name = "width"; reason_jsx_name = "width"; type_ = String (* number | *) };
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/textarea *)
let textarea_html_attributes =
  [
    Attribute { name = "autocomplete"; jsx_name = "auto_complete"; reason_jsx_name = "auto_complete"; type_ = String };
    Attribute { name = "autofocus"; jsx_name = "auto_focus"; reason_jsx_name = "auto_focus"; type_ = Bool };
    Attribute { name = "cols"; jsx_name = "cols"; reason_jsx_name = "cols"; type_ = Int (* number *) };
    Attribute { name = "dirName"; jsx_name = "dir_name"; reason_jsx_name = "dir_name"; type_ = String };
    Attribute { name = "disabled"; jsx_name = "disabled"; reason_jsx_name = "disabled"; type_ = Bool };
    Attribute { name = "form"; jsx_name = "form"; reason_jsx_name = "form"; type_ = String };
    Attribute { name = "maxlength"; jsx_name = "max_length"; reason_jsx_name = "max_length"; type_ = Int (* number *) };
    Attribute { name = "minlength"; jsx_name = "min_length"; reason_jsx_name = "min_length"; type_ = Int (* number *) };
    Attribute { name = "name"; jsx_name = "name"; reason_jsx_name = "name"; type_ = String };
    Attribute { name = "placeholder"; jsx_name = "placeholder"; reason_jsx_name = "placeholder"; type_ = String };
    Attribute { name = "readonly"; jsx_name = "read_only"; reason_jsx_name = "read_only"; type_ = Bool };
    Attribute { name = "required"; jsx_name = "required"; reason_jsx_name = "required"; type_ = Bool };
    Attribute { name = "rows"; jsx_name = "rows"; reason_jsx_name = "rows"; type_ = Int (* number *) };
    Attribute { name = "value"; jsx_name = "value"; reason_jsx_name = "value"; type_ = String (* | ReadonlyArray<String> | number *) };
    Attribute { name = "wrap"; jsx_name = "wrap"; reason_jsx_name = "wrap"; type_ = String };
    Event { jsx_name = "on_change"; type_ = Form };
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/td *)
(* TODO: Add a few deprecated attrs *)
let td_html_attributes =
  [
    Attribute { name = "align"; jsx_name = "align"; reason_jsx_name = "align"; type_ = String (* type_= "left" | "center" | "right" | "justify" | "char" *) };
    Attribute { name = "colspan"; jsx_name = "col_span"; reason_jsx_name = "col_span"; type_ = Int (* number *) };
    Attribute { name = "headers"; jsx_name = "headers"; reason_jsx_name = "headers"; type_ = String };
    Attribute { name = "rowspan"; jsx_name = "rowspan"; reason_jsx_name = "rowspan"; type_ = Int (* number *) };
    Attribute { name = "scope"; jsx_name = "scope"; reason_jsx_name = "scope"; type_ = String };
    Attribute { name = "abbr"; jsx_name = "abbr"; reason_jsx_name = "abbr"; type_ = String };
    Attribute { name = "height"; jsx_name = "height"; reason_jsx_name = "height"; type_ = String (* number | *) };
    Attribute { name = "width"; jsx_name = "width"; reason_jsx_name = "width"; type_ = String (* number | *) };
    Attribute { name = "valign"; jsx_name = "valign"; reason_jsx_name = "valign"; type_ = String (* "top" | "middle" | "bottom" | "baseline" *) };
  ]

let th_html_attributes =
  [
    Attribute { name = "align"; jsx_name = "align"; reason_jsx_name = "align"; type_ = String (* "left" | "center" | "right" | "justify" | "char" *) };
    Attribute { name = "colspan"; jsx_name = "col_span"; reason_jsx_name = "col_span"; type_ = Int (* number *) };
    Attribute { name = "headers"; jsx_name = "headers"; reason_jsx_name = "headers"; type_ = String };
    Attribute { name = "rowspan"; jsx_name = "row_span"; reason_jsx_name = "row_span"; type_ = Int (* number *) };
    Attribute { name = "scope"; jsx_name = "scope"; reason_jsx_name = "scope"; type_ = String };
    Attribute { name = "abbr"; jsx_name = "abbr"; reason_jsx_name = "abbr"; type_ = String };
  ]

let time_html_attributes =
  [
    Attribute { name = "datetime"; jsx_name = "datetime"; reason_jsx_name = "datetime"; type_ = String };
  ]

let track_html_attributes =
  [
    Attribute { name = "default"; jsx_name = "default"; reason_jsx_name = "default"; type_ = Bool };
    Attribute { name = "kind"; jsx_name = "kind"; reason_jsx_name = "kind"; type_ = String };
    Attribute { name = "label"; jsx_name = "label"; reason_jsx_name = "label"; type_ = String };
    Attribute { name = "src"; jsx_name = "src"; reason_jsx_name = "src"; type_ = String };
    Attribute { name = "srclang"; jsx_name = "srclang"; reason_jsx_name = "srclang"; type_ = String };
  ]

(* https://developer.mozilla.org/en-US/docs/Web/HTML/Element/video *)
let video_html_attributes =
  [
    Attribute { name = "autoplay"; jsx_name = "auto_play"; reason_jsx_name = "auto_play"; type_ = Bool };
    Attribute { name = "controls"; jsx_name = "controls"; reason_jsx_name = "controls"; type_ = Bool };
    Attribute { name = "controlslist"; jsx_name = "controls_list"; reason_jsx_name = "controls_list"; type_ = String };
    Attribute { name = "crossorigin"; jsx_name = "cross_origin"; reason_jsx_name = "cross_origin"; type_ = String };
    Attribute { name = "disablepictureinpicture"; jsx_name = "disable_picture_in_picture"; reason_jsx_name = "disable_picture_in_picture"; type_ = Bool };
    Attribute { name = "disableremoteplayback"; jsx_name = "disable_remote_playback"; reason_jsx_name = "disable_remote_playback"; type_ = Bool };
    Attribute { name = "height"; jsx_name = "height"; reason_jsx_name = "height"; type_ = String (* number | *) };
    Attribute { name = "loop"; jsx_name = "loop"; reason_jsx_name = "loop"; type_ = Bool };
    Attribute { name = "muted"; jsx_name = "muted"; reason_jsx_name = "muted"; type_ = Bool };
    Attribute { name = "playsinline"; jsx_name = "plays_inline"; reason_jsx_name = "plays_inline"; type_ = Bool };
    Attribute { name = "poster"; jsx_name = "poster"; reason_jsx_name = "poster"; type_ = String };
    Attribute { name = "preload"; jsx_name = "preload"; reason_jsx_name = "preload"; type_ = String };
    Attribute { name = "src"; jsx_name = "src"; reason_jsx_name = "src"; type_ = String };
    Attribute { name = "width"; jsx_name = "width"; reason_jsx_name = "width"; type_ = String (* number | *) };
  ]

module SVG = struct
  (* "https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/" *)

  let core_attributes =
    (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/Core *)
    [
      Attribute { name = "id"; jsx_name = "id"; reason_jsx_name = "id"; type_ = String };
      Attribute { name = "lang"; jsx_name = "lang"; reason_jsx_name = "lang"; type_ = String };
      Attribute { name = "tabindex"; jsx_name = "tab_index"; reason_jsx_name = "tab_index"; type_ = Int };
      Attribute { name = "xml:base"; jsx_name = "xml_base"; reason_jsx_name = "xml_base"; type_ = String };
      Attribute { name = "xml:lang"; jsx_name = "xml_lang"; reason_jsx_name = "xml_lang"; type_ = String };
      Attribute { name = "xml:space"; jsx_name = "xml_space"; reason_jsx_name = "xml_space"; type_ = String };
    ]

  let styling_attributes =
    (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/Styling *)
    [
      Attribute { name = "class"; jsx_name = "class_name"; reason_jsx_name = "class_name"; type_ = String };
      Attribute { name = "style"; jsx_name = "style"; reason_jsx_name = "style"; type_ = Style }
    ]

  let presentation_attributes =
    (* Presentation attributes *)
    [
      Attribute { name = "alignment-baseline"; jsx_name = "alignment_baseline"; reason_jsx_name = "alignment_baseline"; type_ = String (* "auto" | "baseline" | "before-edge" | "text-before-edge" | "middle" | "central" | "after-edge" "text-after-edge" | "ideographic" | "alphabetic" | "hanging" | "mathematical" | "inherit" *) };
      Attribute { name = "baseline-shift"; jsx_name = "baseline_shift"; reason_jsx_name = "baseline_shift"; type_ = String (* "auto" | "baseline" | "before-edge" | "text-before-edge" | "middle" | "central" | "after-edge" "text-after-edge" | "ideographic" | "alphabetic" | "hanging" | "mathematical" | "inherit" *) };
      Attribute { name = "clip"; jsx_name = "clip"; reason_jsx_name = "clip"; type_ = String (* number | *) };
      Attribute { name = "clip-path"; jsx_name = "clip_path"; reason_jsx_name = "clip_path"; type_ = (* none|<FuncIRI>|inherit *) String };
      Attribute { name = "clip-rule"; jsx_name = "clip_rule"; reason_jsx_name = "clip_rule"; type_ = (* number | "linearRGB" | "inherit" *) String };
      Attribute { name = "color"; jsx_name = "color"; reason_jsx_name = "color"; type_ = String (* number | *) };
      Attribute { name = "color-interpolation"; jsx_name = "color_interpolation"; reason_jsx_name = "color_interpolation"; type_ = String };
      Attribute { name = "color-interpolation-filters"; jsx_name = "color_interpolation_filters"; reason_jsx_name = "color_interpolation_filters"; type_ = String };
      Attribute { name = "color-profile"; jsx_name = "color_profile"; reason_jsx_name = "color_profile"; type_ = String (* number | *) };
      Attribute { name = "color-rendering"; jsx_name = "color_rendering"; reason_jsx_name = "color_rendering"; type_ = String (* number | *) };
      Attribute { name = "cursor"; jsx_name = "cursor"; reason_jsx_name = "cursor"; type_ = String (* number | *) };
      Attribute { name = "direction"; jsx_name = "direction"; reason_jsx_name = "direction"; type_ = String (* number | *) };
      Attribute { name = "display"; jsx_name = "display"; reason_jsx_name = "display"; type_ = String (* number | *) };
      Attribute { name = "divisor"; jsx_name = "divisor"; reason_jsx_name = "divisor"; type_ = String (* number | *) };
      Attribute { name = "dominant-baseline"; jsx_name = "dominant_baseline"; reason_jsx_name = "dominant_baseline"; type_ = String };
      Attribute { name = "enable-background"; jsx_name = "enable_background"; reason_jsx_name = "enable_background"; type_ = String };
      Attribute { name = "fill"; jsx_name = "fill"; reason_jsx_name = "fill"; type_ = String };
      Attribute { name = "fill-opacity"; jsx_name = "fill_opacity"; reason_jsx_name = "fill_opacity"; type_ = String (* number | *) };
      Attribute { name = "fill-rule"; jsx_name = "fill_rule"; reason_jsx_name = "fill_rule"; type_ = String (* type_= "nonzero" | "evenodd" | "inherit" *) };
      Attribute { name = "filter"; jsx_name = "filter"; reason_jsx_name = "filter"; type_ = String };
      Attribute { name = "flood-color"; jsx_name = "flood_color"; reason_jsx_name = "flood_color"; type_ = String (* number | *) };
      Attribute { name = "flood-opacity"; jsx_name = "flood_opacity"; reason_jsx_name = "flood_opacity"; type_ = String (* number | *) };
      Attribute { name = "font-family"; jsx_name = "font_family"; reason_jsx_name = "font_family"; type_ = String };
      Attribute { name = "font-size"; jsx_name = "font_size"; reason_jsx_name = "font_size"; type_ = String (* number | *) };
      Attribute { name = "font-size-adjust"; jsx_name = "font_size_adjust"; reason_jsx_name = "font_size_adjust"; type_ = String };
      Attribute { name = "font-stretch"; jsx_name = "font_stretch"; reason_jsx_name = "font_stretch"; type_ = String (* number | *) };
      Attribute { name = "font-style"; jsx_name = "font_style"; reason_jsx_name = "font_style"; type_ = String (* number | *) };
      Attribute { name = "font-variant"; jsx_name = "font_variant"; reason_jsx_name = "font_variant"; type_ = String (* number | *) };
      Attribute { name = "font-weight"; jsx_name = "font_weight"; reason_jsx_name = "font_weight"; type_ = String (* number | *) };
      Attribute { name = "glyph-orientation-horizontal"; jsx_name = "glyph_orientation_horizontal"; reason_jsx_name = "glyph_orientation_horizontal"; type_ = String (* number | *) };
      Attribute { name = "glyph-orientation-vertical"; jsx_name = "glyph_orientation_vertical"; reason_jsx_name = "glyph_orientation_vertical"; type_ = String (* number | *) };
      Attribute { name = "image-rendering"; jsx_name = "image_rendering"; reason_jsx_name = "image_rendering"; type_ = String };
      Attribute { name = "kerning"; jsx_name = "kerning"; reason_jsx_name = "kerning"; type_ = String (* number | *) };
      Attribute { name = "letter-spacing"; jsx_name = "letter_spacing"; reason_jsx_name = "letter_spacing"; type_ = String };
      Attribute { name = "lighting-color"; jsx_name = "lighting_color"; reason_jsx_name = "lighting_color"; type_ = String };
      Attribute { name = "marker-end"; jsx_name = "marker_end"; reason_jsx_name = "marker_end"; type_ = String };
      Attribute { name = "marker-mid"; jsx_name = "marker_mid"; reason_jsx_name = "marker_mid"; type_ = String };
      Attribute { name = "marker-start"; jsx_name = "marker_start"; reason_jsx_name = "marker_start"; type_ = String };
      Attribute { name = "mask"; jsx_name = "mask"; reason_jsx_name = "mask"; type_ = String };
      Attribute { name = "opacity"; jsx_name = "opacity"; reason_jsx_name = "opacity"; type_ = String (* number | *) };
      Attribute { name = "operator"; jsx_name = "operator"; reason_jsx_name = "operator"; type_ = String (* number | *) };
      Attribute { name = "overflow"; jsx_name = "overflow"; reason_jsx_name = "overflow"; type_ = String (* number | *) };
      Attribute { name = "pointer-events"; jsx_name = "pointer_events"; reason_jsx_name = "pointer_events"; type_ = String };
      Attribute { name = "shape-rendering"; jsx_name = "shape_rendering"; reason_jsx_name = "shape_rendering"; type_ = String };
      Attribute { name = "specularConstant"; jsx_name = "specular_constant"; reason_jsx_name = "specular_constant"; type_ = String }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/specular_constant *)
      Attribute { name = "specularExponent"; jsx_name = "specular_exponent"; reason_jsx_name = "specular_exponent"; type_ = String }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/specular_exponent *)
      Attribute { name = "solid-color"; jsx_name = "solid_color"; reason_jsx_name = "solid_color"; type_ = String };
      Attribute { name = "solid-opacity"; jsx_name = "solid_opacity"; reason_jsx_name = "solid_opacity"; type_ = String };
      Attribute { name = "stop-color"; jsx_name = "stop_color"; reason_jsx_name = "stop_color"; type_ = String };
      Attribute { name = "stop-opacity"; jsx_name = "stop_opacity"; reason_jsx_name = "stop_opacity"; type_ = String (* number | *) };
      Attribute { name = "stroke"; jsx_name = "stroke"; reason_jsx_name = "stroke"; type_ = String };
      Attribute { name = "stroke-dasharray"; jsx_name = "stroke_dasharray"; reason_jsx_name = "stroke_dasharray"; type_ = String };
      Attribute { name = "stroke-opacity"; jsx_name = "stroke_opacity"; reason_jsx_name = "stroke_opacity"; type_ = String };
      Attribute { name = "stroke-miterlimit"; jsx_name = "stroke_miterlimit"; reason_jsx_name = "stroke_miterlimit"; type_ = String };
      Attribute { name = "stroke-dashoffset"; jsx_name = "stroke_dashoffset"; reason_jsx_name = "stroke_dashoffset"; type_ = String };
      Attribute { name = "stroke-linecap"; jsx_name = "stroke_linecap"; reason_jsx_name = "stroke_linecap"; type_ = String (* type_= "butt" | "round" | "square" | "inherit" *) };
      Attribute { name = "stroke-linejoin"; jsx_name = "stroke_linejoin"; reason_jsx_name = "stroke_linejoin"; type_ = String (* type_= "arcs" | "bevel" | "miter" | "miter-clip" | "round" *) };
      Attribute { name = "text-anchor"; jsx_name = "text_anchor"; reason_jsx_name = "text_anchor"; type_ = String };
      Attribute { name = "text-decoration"; jsx_name = "text_decoration"; reason_jsx_name = "text_decoration"; type_ = String };
      Attribute { name = "text-rendering"; jsx_name = "text_rendering"; reason_jsx_name = "text_rendering"; type_ = String };
      Attribute { name = "transform"; jsx_name = "transform"; reason_jsx_name = "transform"; type_ = String };
      Attribute { name = "transform-origin"; jsx_name = "transform_origin"; reason_jsx_name = "transform_origin"; type_ = String }; (* Does it exist? *)
      Attribute { name = "unicode-bidi"; jsx_name = "unicode_bidi"; reason_jsx_name = "unicode_bidi"; type_ = String (* number | *) };
      Attribute { name = "vector-effect"; jsx_name = "vector_effect"; reason_jsx_name = "vector_effect"; type_ = String (* number | *) };
      Attribute { name = "word-spacing"; jsx_name = "word_spacing"; reason_jsx_name = "word_spacing"; type_ = String (* number | *) };
      Attribute { name = "writing-mode"; jsx_name = "writing_mode"; reason_jsx_name = "writing_mode"; type_ = String (* number | *) };
    ]

  let filters_attributes =
    (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute#filters_attributes *)
    [
      (* Filter primitive attributes *)
      Attribute { name = "height"; jsx_name = "height"; reason_jsx_name = "height"; type_ = String (* number | *) };
      Attribute { name = "width"; jsx_name = "width"; reason_jsx_name = "width"; type_ = String (* number | *) };
      Attribute { name = "result"; jsx_name = "result"; reason_jsx_name = "result"; type_ = String };
      Attribute { name = "x"; jsx_name = "x"; reason_jsx_name = "x"; type_ = String (* number | *) };
      Attribute { name = "y"; jsx_name = "y"; reason_jsx_name = "y"; type_ = String (* number | *) };
      (* Transfer function attributes type, table_values, slope, intercept,
         amplitude, exponent, offset *)
      Attribute { name = "type"; jsx_name = "type"; reason_jsx_name = "type_"; type_ = String };
      Attribute { name = "exponent"; jsx_name = "exponent"; reason_jsx_name = "exponent"; type_ = String (* number | *) };
      Attribute { name = "slope"; jsx_name = "slope"; reason_jsx_name = "slope"; type_ = String (* number | *) };
      Attribute { name = "amplitude"; jsx_name = "amplitude"; reason_jsx_name = "amplitude"; type_ = String (* number | *) };
      Attribute { name = "intercept"; jsx_name = "intercept"; reason_jsx_name = "intercept"; type_ = String (* number | *) };
      (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/table_values *)
      Attribute { name = "tableValues"; jsx_name = "table_values"; reason_jsx_name = "table_values"; type_ = String (* number | *) };

      (* Animation target element attributes *)
      Attribute { name = "href"; jsx_name = "href"; reason_jsx_name = "href"; type_ = String };

      (* Animation attribute target attributes*)
      (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/attribute_name *)
      Attribute { name = "attributeName"; jsx_name = "attribute_name"; reason_jsx_name = "attribute_name"; type_ = String };
      (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/attribute_type *)
      Attribute { name = "attributeType"; jsx_name = "attribute_type"; reason_jsx_name = "attribute_type"; type_ = String };

      (* Animation timing attributes begin, dur, end, min, max, restart,
         repeat_count, repeat_dur, fill *)
      Attribute { name = "begin"; jsx_name = "begin"; reason_jsx_name = "begin_"; type_ = String (* number | *) };
      Attribute { name = "dur"; jsx_name = "dur"; reason_jsx_name = "dur"; type_ = String (* number | *) };
      Attribute { name = "end"; jsx_name = "end"; reason_jsx_name = "end_"; type_ = String (* number | *) };
      Attribute { name = "max"; jsx_name = "max"; reason_jsx_name = "max"; type_ = String (* number | *) };
      Attribute { name = "min"; jsx_name = "min"; reason_jsx_name = "min"; type_ = String (* number | *) };
      Attribute { name = "repeatCount"; jsx_name = "repeat_count"; reason_jsx_name = "repeat_count"; type_ = String (* number | *) };
      Attribute { name = "restart"; jsx_name = "restart"; reason_jsx_name = "restart"; type_ = String (* number | *) };
      Attribute { name = "repeatDur"; jsx_name = "repeat_dur"; reason_jsx_name = "repeat_dur"; type_ = String (* number | *) };
      Attribute { name = "fill"; jsx_name = "fill"; reason_jsx_name = "fill"; type_ = String };

      (* Animation value attributes *)
      (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/calc_mode *)
      Attribute { name = "calcMode"; jsx_name = "calc_mode"; reason_jsx_name = "calc_mode"; type_ = String (* number | *) };
      Attribute { name = "values"; jsx_name = "values"; reason_jsx_name = "values"; type_ = String };
      Attribute { name = "keySplines"; jsx_name = "key_splines"; reason_jsx_name = "key_splines"; type_ = String (* number | *) };
      Attribute { name = "keyTimes"; jsx_name = "key_times"; reason_jsx_name = "key_times"; type_ = String (* number | *) };
      Attribute { name = "from"; jsx_name = "from"; reason_jsx_name = "from"; type_ = String (* number | *) };
      Attribute { name = "to"; jsx_name = "to"; reason_jsx_name = "to_"; type_ = String (* number | *) };
      Attribute { name = "by"; jsx_name = "by"; reason_jsx_name = "by"; type_ = String (* number | *) };

      (* Animation addition attributes *)
      Attribute { name = "accumulate"; jsx_name = "accumulate"; reason_jsx_name = "accumulate"; type_ = String (* type_= "none" | "sum" *) };
      Attribute { name = "additive"; jsx_name = "additive"; reason_jsx_name = "additive"; type_ = String (* type_= "replace" | "sum" *) };
    ]

  let html_attributes =
    (* These are valid SVG attributes which are HTML Attributes as well *)
    [
      Attribute { name = "color"; jsx_name = "color"; reason_jsx_name = "color"; type_ = String };
      Attribute { name = "id"; jsx_name = "id"; reason_jsx_name = "id"; type_ = String };
      Attribute { name = "lang"; jsx_name = "lang"; reason_jsx_name = "lang"; type_ = String };
      Attribute { name = "media"; jsx_name = "media"; reason_jsx_name = "media"; type_ = String };
      Attribute { name = "method"; jsx_name = "method"; reason_jsx_name = "method_"; type_ = String };
      Attribute { name = "name"; jsx_name = "name"; reason_jsx_name = "name"; type_ = String };
      Attribute { name = "style"; jsx_name = "style"; reason_jsx_name = "style"; type_ = Style };
      Attribute { name = "target"; jsx_name = "target"; reason_jsx_name = "target"; type_ = String };

      (* Other HTML properties supported by SVG elements in browsers *)
      Attribute { name = "role"; jsx_name = "role"; reason_jsx_name = "role"; type_ = aria_role };
      Attribute { name = "tabindex"; jsx_name = "tab_index"; reason_jsx_name = "tab_index"; type_ = Int (* number *) };
      Attribute { name = "cross-origin"; jsx_name = "cross_origin"; reason_jsx_name = "cross_origin"; type_ = String (* "anonymous" | "use-credentials" | "" *) };

      (* SVG Specific attributes *)
      Attribute { name = "accent-height"; jsx_name = "accent_height"; reason_jsx_name = "accent_height"; type_ = String (* number | *) };
      (* Attribute { name = "allowReorder"; jsx_name = "allow_reorder"; reason_jsx_name = "allow_reorder"; type_ = String (* type_= "no" | "yes" *) }; Does it exist? *)
      Attribute { name = "alphabetic"; jsx_name = "alphabetic"; reason_jsx_name = "alphabetic"; type_ = String (* number | *) };
      Attribute { name = "arabic-form"; jsx_name = "arabic_form"; reason_jsx_name = "arabic_form"; type_ = String (* type_= "initial" | "medial" | "terminal" | "isolated" *) };
      Attribute { name = "ascent"; jsx_name = "ascent"; reason_jsx_name = "ascent"; type_ = String (* number | *) };
      (* Attribute { name = "autoReverse"; jsx_name = "auto_reverse"; reason_jsx_name = "auto_reverse"; type_ = Booleanish_string }; Does it exists? *)
      Attribute { name = "azimuth"; jsx_name = "azimuth"; reason_jsx_name = "azimuth"; type_ = String (* number | *) };
      Attribute { name = "baseProfile"; jsx_name = "base_profile"; reason_jsx_name = "base_profile"; type_ = String (* number | *) };
      Attribute { name = "baseFrequency"; jsx_name = "base_frequency"; reason_jsx_name = "base_frequency"; type_ = String (* number | *) };
      Attribute { name = "bbox"; jsx_name = "bbox"; reason_jsx_name = "bbox"; type_ = String (* number | *) };
      Attribute { name = "bias"; jsx_name = "bias"; reason_jsx_name = "bias"; type_ = String (* number | *) };
      (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/cap-height *)
      Attribute { name = "cap-height"; jsx_name = "cap_height"; reason_jsx_name = "cap_height"; type_ = String (* number | *) };
      Attribute { name = "cx"; jsx_name = "cx"; reason_jsx_name = "cx"; type_ = String (* number | *) };
      Attribute { name = "cy"; jsx_name = "cy"; reason_jsx_name = "cy"; type_ = String (* number | *) };
      Attribute { name = "d"; jsx_name = "d"; reason_jsx_name = "d"; type_ = String };
      Attribute { name = "decelerate"; jsx_name = "decelerate"; reason_jsx_name = "decelerate"; type_ = String (* number | *) };
      Attribute { name = "descent"; jsx_name = "descent"; reason_jsx_name = "descent"; type_ = String (* number | *) };
      Attribute { name = "dx"; jsx_name = "dx"; reason_jsx_name = "dx"; type_ = String (* number | *) };
      Attribute { name = "dy"; jsx_name = "dy"; reason_jsx_name = "dy"; type_ = String (* number | *) };
      Attribute { name = "edgeMode"; jsx_name = "edge_mode"; reason_jsx_name = "edge_mode"; type_ = String (* number | *) };
      Attribute { name = "elevation"; jsx_name = "elevation"; reason_jsx_name = "elevation"; type_ = String (* number | *) };
      (* Attribute { name = "externalResourcesRequired"; jsx_name = "external_resources_required"; reason_jsx_name = "external_resources_required"; type_ = Booleanish_string }; Does it exists? *)
      Attribute { name = "filterRes"; jsx_name = "filter_res"; reason_jsx_name = "filter_res"; type_ = String (* number | *) };
      Attribute { name = "filterUnits"; jsx_name = "filter_units"; reason_jsx_name = "filter_units"; type_ = String (* number | *) };
      Attribute { name = "format"; jsx_name = "format"; reason_jsx_name = "format"; type_ = String (* number | *) };
      Attribute { name = "fr"; jsx_name = "fr"; reason_jsx_name = "fr"; type_ = String (* number | *) };
      Attribute { name = "fx"; jsx_name = "fx"; reason_jsx_name = "fx"; type_ = String (* number | *) };
      Attribute { name = "fy"; jsx_name = "fy"; reason_jsx_name = "fy"; type_ = String (* number | *) };
      Attribute { name = "g1"; jsx_name = "g1"; reason_jsx_name = "g1"; type_ = String (* number | *) };
      Attribute { name = "g2"; jsx_name = "g2"; reason_jsx_name = "g2"; type_ = String (* number | *) };
      Attribute { name = "glyph-name"; jsx_name = "glyph_name"; reason_jsx_name = "glyph_name"; type_ = String (* number | *) }; (* Deprecated *)
      Attribute { name = "glyphRef"; jsx_name = "glyph_ref"; reason_jsx_name = "glyph_ref"; type_ = String (* number | *) }; (* Deprecated *)
      Attribute { name = "gradientTransform"; jsx_name = "gradient_transform"; reason_jsx_name = "gradient_transform"; type_ = String }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/gradient_transform *)
      Attribute { name = "gradientUnits"; jsx_name = "gradient_units"; reason_jsx_name = "gradient_units"; type_ = String };
      Attribute { name = "hanging"; jsx_name = "hanging"; reason_jsx_name = "hanging"; type_ = String (* number | *) };
      Attribute { name = "horiz-adv-x"; jsx_name = "horiz_adv_x"; reason_jsx_name = "horiz_adv_x"; type_ = String (* number | *) };
      Attribute { name = "horiz-origin-x"; jsx_name = "horiz_origin_x"; reason_jsx_name = "horiz_origin_x"; type_ = String (* number | *) };
      Attribute { name = "horiz-origin-y"; jsx_name = "horiz_origin_y"; reason_jsx_name = "horiz_origin_y"; type_ = String (* number | *) };
      Attribute { name = "ideographic"; jsx_name = "ideographic"; reason_jsx_name = "ideographic"; type_ = String (* number | *) };
      Attribute { name = "in2"; jsx_name = "in2"; reason_jsx_name = "in2"; type_ = String (* number | *) };
      Attribute { name = "in"; jsx_name = "in"; reason_jsx_name = "in_"; type_ = String };
      Attribute { name = "k1"; jsx_name = "k1"; reason_jsx_name = "k1"; type_ = String (* number | *) };
      Attribute { name = "k2"; jsx_name = "k2"; reason_jsx_name = "k2"; type_ = String (* number | *) };
      Attribute { name = "k3"; jsx_name = "k3"; reason_jsx_name = "k3"; type_ = String (* number | *) };
      Attribute { name = "k4"; jsx_name = "k4"; reason_jsx_name = "k4"; type_ = String (* number | *) };
      Attribute { name = "k"; jsx_name = "k"; reason_jsx_name = "k"; type_ = String (* number | *) };
      Attribute { name = "kernelMatrix"; jsx_name = "kernel_matrix"; reason_jsx_name = "kernel_matrix"; type_ = String (* number | *) };
      Attribute { name = "limitingConeAngle"; jsx_name = "limiting_cone_angle"; reason_jsx_name = "limiting_cone_angle"; type_ = String };
      Attribute { name = "lengthAdjust"; jsx_name = "length_adjust"; reason_jsx_name = "length_adjust"; type_ = String (* number | *) };
      Attribute { name = "local"; jsx_name = "local"; reason_jsx_name = "local"; type_ = String (* number | *) };
      Attribute { name = "marker-mid"; jsx_name = "marker_mid"; reason_jsx_name = "marker_mid"; type_ = String };
      Attribute { name = "marker-start"; jsx_name = "marker_start"; reason_jsx_name = "marker_start"; type_ = String };
      Attribute { name = "marker-units"; jsx_name = "marker_units"; reason_jsx_name = "marker_units"; type_ = String (* number | *) };
      Attribute { name = "markerWidth"; jsx_name = "marker_width"; reason_jsx_name = "marker_width"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/marker_width *)
      Attribute { name = "markerHeight"; jsx_name = "marker_height"; reason_jsx_name = "marker_height"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/marker_height *)
      Attribute { name = "maskUnits"; jsx_name = "mask_units"; reason_jsx_name = "mask_units"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/mask_units *)
      Attribute { name = "maskContentUnits"; jsx_name = "mask_content_units"; reason_jsx_name = "mask_content_units"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/mask_content_units *)
      Attribute { name = "mathematical"; jsx_name = "mathematical"; reason_jsx_name = "mathematical"; type_ = String (* number | *) };
      Attribute { name = "mode"; jsx_name = "mode"; reason_jsx_name = "mode"; type_ = String (* number | *) };
      Attribute { name = "numOctaves"; jsx_name = "num_octaves"; reason_jsx_name = "num_octaves"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/num_octaves *)
      Attribute { name = "offset"; jsx_name = "offset"; reason_jsx_name = "offset"; type_ = String (* number | *) };
      Attribute { name = "order"; jsx_name = "order"; reason_jsx_name = "order"; type_ = String (* number | *) };
      Attribute { name = "orient"; jsx_name = "orient"; reason_jsx_name = "orient"; type_ = String (* number | *) };
      Attribute { name = "orientation"; jsx_name = "orientation"; reason_jsx_name = "orientation"; type_ = String (* number | *) };
      Attribute { name = "origin"; jsx_name = "origin"; reason_jsx_name = "origin"; type_ = String (* number | *) };
      Attribute { name = "overline-thickness"; jsx_name = "overline_thickness"; reason_jsx_name = "overline_thickness"; type_ = String };
      Attribute { name = "overline-position"; jsx_name = "overline_position"; reason_jsx_name = "overline_position"; type_ = String };
      Attribute { name = "paint-order"; jsx_name = "paint_order"; reason_jsx_name = "paint_order"; type_ = String (* number | *) };
      Attribute { name = "panose1"; jsx_name = "panose1"; reason_jsx_name = "panose1"; type_ = String (* number | *) };
      Attribute { name = "path"; jsx_name = "path"; reason_jsx_name = "path"; type_ = String };
      Attribute { name = "pathLength"; jsx_name = "path_length"; reason_jsx_name = "path_length"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/path_length *)
      Attribute { name = "patternContentUnits"; jsx_name = "pattern_content_units"; reason_jsx_name = "pattern_content_units"; type_ = String }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/pattern_content_units *)
      Attribute { name = "patternUnits"; jsx_name = "pattern_units"; reason_jsx_name = "pattern_units"; type_ = String };
      Attribute { name = "points"; jsx_name = "points"; reason_jsx_name = "points"; type_ = String };
      Attribute { name = "pointsAtX"; jsx_name = "points_at_x"; reason_jsx_name = "points_at_x"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/points_at_x *)
      Attribute { name = "pointsAtY"; jsx_name = "points_at_y"; reason_jsx_name = "points_at_y"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/points_at_y *)
      Attribute { name = "pointsAtZ"; jsx_name = "points_at_z"; reason_jsx_name = "points_at_z"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/points_at_z *)
      Attribute { name = "preserveAspectRatio"; jsx_name = "preserve_aspect_ratio"; reason_jsx_name = "preserve_aspect_ratio"; type_ = String }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/preserve_aspect_ratio *)
      Attribute { name = "r"; jsx_name = "r"; reason_jsx_name = "r"; type_ = String (* number | *) };
      Attribute { name = "radius"; jsx_name = "radius"; reason_jsx_name = "radius"; type_ = String (* number | *) };
      Attribute { name = "requiredFeatures"; jsx_name = "required_features"; reason_jsx_name = "required_features"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/required_features *)
      Attribute { name = "refX"; jsx_name = "ref_x"; reason_jsx_name = "ref_x"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/ref_x *)
      Attribute { name = "refY"; jsx_name = "ref_y"; reason_jsx_name = "ref_y"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/ref_y *)
      Attribute { name = "rotate"; jsx_name = "rotate"; reason_jsx_name = "rotate"; type_ = String (* number | *) };
      Attribute { name = "rx"; jsx_name = "rx"; reason_jsx_name = "rx"; type_ = String (* number | *) };
      Attribute { name = "ry"; jsx_name = "ry"; reason_jsx_name = "ry"; type_ = String (* number | *) };
      Attribute { name = "scale"; jsx_name = "scale"; reason_jsx_name = "scale"; type_ = String (* number | *) };
      Attribute { name = "seed"; jsx_name = "seed"; reason_jsx_name = "seed"; type_ = String (* number | *) };
      Attribute { name = "spacing"; jsx_name = "spacing"; reason_jsx_name = "spacing"; type_ = String (* number | *) };
      Attribute { name = "speed"; jsx_name = "speed"; reason_jsx_name = "speed"; type_ = String (* number | *) };
      Attribute { name = "spreadMethod"; jsx_name = "spread_method"; reason_jsx_name = "spread_method"; type_ = String }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/spread_method *)
      Attribute { name = "startOffset"; jsx_name = "start_offset"; reason_jsx_name = "start_offset"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/start_offset *)
      Attribute { name = "stdDeviation"; jsx_name = "std_deviation"; reason_jsx_name = "std_deviation"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/std_deviation *)
      Attribute { name = "stemh"; jsx_name = "stemh"; reason_jsx_name = "stemh"; type_ = String (* number | *) };
      Attribute { name = "stemv"; jsx_name = "stemv"; reason_jsx_name = "stemv"; type_ = String (* number | *) };
      Attribute { name = "stitchTiles"; jsx_name = "stitch_tiles"; reason_jsx_name = "stitch_tiles"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/stitch_tiles *)
      Attribute { name = "strikethrough-position"; jsx_name = "strikethrough_position"; reason_jsx_name = "strikethrough_position"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/strikethrough-position *)
      Attribute { name = "strikethrough-thickness"; jsx_name = "strikethrough_thickness"; reason_jsx_name = "strikethrough_thickness"; type_ = String (* number | *) };
      Attribute { name = "stroke-width"; jsx_name = "stroke_width"; reason_jsx_name = "stroke_width"; type_ = String (* number | *) };
      Attribute { name = "surfaceScale"; jsx_name = "surface_scale"; reason_jsx_name = "surface_scale"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/surface_scale *)
      Attribute { name = "systemLanguage"; jsx_name = "system_language"; reason_jsx_name = "system_language"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/system_language *)
      Attribute { name = "targetX"; jsx_name = "target_x"; reason_jsx_name = "target_x"; type_ = String (* number | *) };
      Attribute { name = "targetY"; jsx_name = "target_y"; reason_jsx_name = "target_y"; type_ = String (* number | *) };
      Attribute { name = "textLength"; jsx_name = "text_length"; reason_jsx_name = "text_length"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/text_length *)
      Attribute { name = "u1"; jsx_name = "u1"; reason_jsx_name = "u1"; type_ = String (* number | *) };
      Attribute { name = "u2"; jsx_name = "u2"; reason_jsx_name = "u2"; type_ = String (* number | *) };
      Attribute { name = "unicode"; jsx_name = "unicode"; reason_jsx_name = "unicode"; type_ = String (* number | *) };
      (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/unicode-range *)
      Attribute { name = "unicode-range"; jsx_name = "unicode_range"; reason_jsx_name = "unicode_range"; type_ = String (* number | *) };
      (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/units-per-em *)
      Attribute { name = "units-per-em"; jsx_name = "units_per_em"; reason_jsx_name = "units_per_em"; type_ = String (* number | *) };
      Attribute { name = "v-alphabetic"; jsx_name = "v_alphabetic"; reason_jsx_name = "v_alphabetic"; type_ = String (* number | *) }; (* Deprecated *) (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/v-alphabetic *)
      Attribute { name = "version"; jsx_name = "version"; reason_jsx_name = "version"; type_ = String };
      Attribute { name = "vert-adv-y"; jsx_name = "vert_adv_y"; reason_jsx_name = "vert_adv_y"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/vert-adv-y *)
      Attribute { name = "vert-origin-x"; jsx_name = "vert_origin_x"; reason_jsx_name = "vert_origin_x"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/vert-origin-x *)
      Attribute { name = "vert-origin-y"; jsx_name = "vert_origin_y"; reason_jsx_name = "vert_origin_y"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/vert-origin-y *)
      Attribute { name = "v-hanging"; jsx_name = "v_hanging"; reason_jsx_name = "v_hanging"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/v-hanging *)
      Attribute { name = "v-ideographic"; jsx_name = "v_ideographic"; reason_jsx_name = "v_ideographic"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/v-ideographic *)
      Attribute { name = "viewBox"; jsx_name = "view_box"; reason_jsx_name = "view_box"; type_ = String }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/view_box *)
      Attribute { name = "viewTarget"; jsx_name = "view_target"; reason_jsx_name = "view_target"; type_ = String (* number | *) }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/view_target *)
      Attribute { name = "visibility"; jsx_name = "visibility"; reason_jsx_name = "visibility"; type_ = String (* number | *) };
      Attribute { name = "widths"; jsx_name = "widths"; reason_jsx_name = "widths"; type_ = String (* number | *) };
      Attribute { name = "x1"; jsx_name = "x1"; reason_jsx_name = "x1"; type_ = String (* number | *) };
      Attribute { name = "x2"; jsx_name = "x2"; reason_jsx_name = "x2"; type_ = String (* number | *) };
      Attribute { name = "xChannelSelector"; jsx_name = "x_channel_selector"; reason_jsx_name = "x_channel_selector"; type_ = String }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/x_channel_selector *)
      Attribute { name = "xHeight"; jsx_name = "x_height"; reason_jsx_name = "x_height"; type_ = String (* number | *) };
      (* All xlink: attributes are rendered like this and are deprecated *)
      Attribute { name = "xlink:actuate"; jsx_name = "xlink_actuate"; reason_jsx_name = "xlink_actuate"; type_ = String };
      Attribute { name = "xlink:arcrole"; jsx_name = "xlink_arcrole"; reason_jsx_name = "xlink_arcrole"; type_ = String };
      Attribute { name = "xlink:href"; jsx_name = "xlink_href"; reason_jsx_name = "xlink_href"; type_ = String };
      Attribute { name = "xlink:role"; jsx_name = "xlink_role"; reason_jsx_name = "xlink_role"; type_ = String };
      Attribute { name = "xlink:show"; jsx_name = "xlink_show"; reason_jsx_name = "xlink_show"; type_ = String };
      Attribute { name = "xlink:title"; jsx_name = "xlink_title"; reason_jsx_name = "xlink_title"; type_ = String };
      Attribute { name = "xlink:type"; jsx_name = "xlink_type"; reason_jsx_name = "xlink_type"; type_ = String }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/xlink:type *)
      Attribute { name = "xml:base"; jsx_name = "xml_base"; reason_jsx_name = "xml_base"; type_ = String }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/xml:base *)
      Attribute { name = "xml:lang"; jsx_name = "xml_lang"; reason_jsx_name = "xml_lang"; type_ = String }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/xml:lang *)
      Attribute { name = "xmlns"; jsx_name = "xmlns"; reason_jsx_name = "xmlns"; type_ = String };
      Attribute { name = "xmlns:xlink"; jsx_name = "xmlns_xlink"; reason_jsx_name = "xmlns_xlink"; type_ = String };
      Attribute { name = "xmlSpace"; jsx_name = "xml_space"; reason_jsx_name = "xml_space"; type_ = String };
      Attribute { name = "y1"; jsx_name = "y1"; reason_jsx_name = "y1"; type_ = String (* number | *) };
      Attribute { name = "y2"; jsx_name = "y2"; reason_jsx_name = "y2"; type_ = String (* number | *) };
      Attribute { name = "yChannelSelector"; jsx_name = "y_channel_selector"; reason_jsx_name = "y_channel_selector"; type_ = String }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/y_channel_selector *)
      Attribute { name = "z"; jsx_name = "z"; reason_jsx_name = "z"; type_ = String (* number | *) };
      Attribute { name = "zoomAndPan"; jsx_name = "zoom_and_pan"; reason_jsx_name = "zoom_and_pan"; type_ = String }; (* https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/zoom_and_pan *) (* Deprecated *)
    ]

  let attributes = html_attributes @ filters_attributes @ presentation_attributes @ styling_attributes @ core_attributes
end

let web_view_html_attributes =
  [
    Attribute { name = "allowfullcreen"; jsx_name = "allow_full_screen"; reason_jsx_name = "allow_full_screen"; type_ = Bool };
    Attribute { name = "autofocus"; jsx_name = "auto_focus"; reason_jsx_name = "auto_focus"; type_ = Bool };
    Attribute { name = "autoSize"; jsx_name = "auto_size"; reason_jsx_name = "auto_size"; type_ = Bool };
    Attribute { name = "blinkFeatures"; jsx_name = "blink_features"; reason_jsx_name = "blink_features"; type_ = String };
    Attribute { name = "disableBlinkFeatures"; jsx_name = "disable_blink_features"; reason_jsx_name = "disable_blink_features"; type_ = String };
    Attribute { name = "disableGuestResize"; jsx_name = "disable_guest_resize"; reason_jsx_name = "disable_guest_resize"; type_ = Bool };
    Attribute { name = "disableWebSecurity"; jsx_name = "disable_web_security"; reason_jsx_name = "disable_web_security"; type_ = Bool };
    Attribute { name = "guestInstance"; jsx_name = "guest_instance"; reason_jsx_name = "guest_instance"; type_ = String };
    Attribute { name = "httpReferrer"; jsx_name = "http_referrer"; reason_jsx_name = "http_referrer"; type_ = String };
    Attribute { name = "nodeIntegration"; jsx_name = "node_integration"; reason_jsx_name = "node_integration"; type_ = Bool };
    Attribute { name = "partition"; jsx_name = "partition"; reason_jsx_name = "partition"; type_ = String };
    Attribute { name = "plugins"; jsx_name = "plugins"; reason_jsx_name = "plugins"; type_ = Bool };
    Attribute { name = "preload"; jsx_name = "preload"; reason_jsx_name = "preload"; type_ = String };
    Attribute { name = "src"; jsx_name = "src"; reason_jsx_name = "src"; type_ = String };
    Attribute { name = "userAgent"; jsx_name = "user_agent"; reason_jsx_name = "user_agent"; type_ = String };
    Attribute { name = "webPreferences"; jsx_name = "web_preferences"; reason_jsx_name = "web_preferences"; type_ = String };
  ]

let common_html_attributes = element_attributes @ react_attributes @ global_attributes @ global_event_handlers @ aria_attributes

let html_elements =
  [
    { tag = "a"; attributes = common_html_attributes @ anchor_html_attributes };
    { tag = "abbr"; attributes = common_html_attributes };
    { tag = "address"; attributes = common_html_attributes };
    { tag = "area"; attributes = common_html_attributes @ area_html_attributes };
    { tag = "article"; attributes = common_html_attributes };
    { tag = "aside"; attributes = common_html_attributes };
    { tag = "audio"; attributes = common_html_attributes @ media_html_attributes };
    { tag = "b"; attributes = common_html_attributes };
    { tag = "base"; attributes = common_html_attributes @ base_html_attributes };
    { tag = "bdi"; attributes = common_html_attributes };
    { tag = "bdo"; attributes = common_html_attributes };
    { tag = "big"; attributes = common_html_attributes };
    { tag = "blockquote"; attributes = common_html_attributes @ blockquote_html_attributes };
    { tag = "body"; attributes = common_html_attributes };
    { tag = "br"; attributes = common_html_attributes };
    { tag = "button"; attributes = common_html_attributes @ button_html_attributes };
    { tag = "canvas"; attributes = common_html_attributes @ canvas_html_attributes };
    { tag = "caption"; attributes = common_html_attributes };
    { tag = "cite"; attributes = common_html_attributes };
    { tag = "code"; attributes = common_html_attributes };
    { tag = "col"; attributes = common_html_attributes @ col_html_attributes };
    { tag = "colgroup"; attributes = common_html_attributes @ colgroup_html_attributes };
    { tag = "data"; attributes = common_html_attributes @ data_html_attributes };
    { tag = "datalist"; attributes = common_html_attributes };
    { tag = "dd"; attributes = common_html_attributes };
    { tag = "del"; attributes = common_html_attributes @ del_html_attributes };
    { tag = "details"; attributes = common_html_attributes @ details_html_attributes };
    { tag = "dfn"; attributes = common_html_attributes };
    { tag = "dialog"; attributes = common_html_attributes @ dialog_html_attributes };
    { tag = "div"; attributes = common_html_attributes };
    { tag = "dl"; attributes = common_html_attributes };
    { tag = "dt"; attributes = common_html_attributes };
    { tag = "em"; attributes = common_html_attributes };
    { tag = "embed"; attributes = common_html_attributes @ embed_html_attributes };
    { tag = "fieldset"; attributes = common_html_attributes @ fieldset_html_attributes };
    { tag = "figcaption"; attributes = common_html_attributes };
    { tag = "figure"; attributes = common_html_attributes };
    { tag = "footer"; attributes = common_html_attributes };
    { tag = "form"; attributes = common_html_attributes @ form_html_attributes };
    { tag = "h1"; attributes = common_html_attributes };
    { tag = "h2"; attributes = common_html_attributes };
    { tag = "h3"; attributes = common_html_attributes };
    { tag = "h4"; attributes = common_html_attributes };
    { tag = "h5"; attributes = common_html_attributes };
    { tag = "h6"; attributes = common_html_attributes };
    { tag = "head"; attributes = common_html_attributes };
    { tag = "header"; attributes = common_html_attributes };
    { tag = "hgroup"; attributes = common_html_attributes };
    { tag = "hr"; attributes = common_html_attributes };
    { tag = "html"; attributes = common_html_attributes @ html_html_attributes };
    { tag = "i"; attributes = common_html_attributes };
    { tag = "iframe"; attributes = common_html_attributes @ iframe_html_attributes };
    { tag = "img"; attributes = common_html_attributes @ img_html_attributes };
    { tag = "input"; attributes = common_html_attributes @ input_html_attributes };
    { tag = "ins"; attributes = common_html_attributes @ ins_html_attributes };
    { tag = "kbd"; attributes = common_html_attributes };
    { tag = "keygen"; attributes = common_html_attributes @ keygen_html_attributes };
    { tag = "label"; attributes = common_html_attributes @ label_html_attributes };
    { tag = "legend"; attributes = common_html_attributes };
    { tag = "li"; attributes = common_html_attributes @ li_html_attributes };
    { tag = "link"; attributes = common_html_attributes @ link_html_attributes };
    { tag = "main"; attributes = common_html_attributes };
      { tag = "map"; attributes = common_html_attributes @ map_html_attributes };
    { tag = "mark"; attributes = common_html_attributes };
    { tag = "menu"; attributes = common_html_attributes @ menu_html_attributes };
    { tag = "menuitem"; attributes = common_html_attributes };
    { tag = "meta"; attributes = common_html_attributes @ meta_html_attributes };
    { tag = "meter"; attributes = common_html_attributes @ meter_html_attributes };
    { tag = "nav"; attributes = common_html_attributes };
    { tag = "noindex"; attributes = common_html_attributes };
    { tag = "noscript"; attributes = common_html_attributes };
    { tag = "object"; attributes = common_html_attributes @ object_html_attributes };
    { tag = "ol"; attributes = common_html_attributes @ ol_html_attributes };
    { tag = "optgroup"; attributes = common_html_attributes @ optgroup_html_attributes };
    { tag = "option"; attributes = common_html_attributes @ option_html_attributes };
    { tag = "output"; attributes = common_html_attributes @ output_html_attributes };
    { tag = "p"; attributes = common_html_attributes };
    { tag = "param"; attributes = common_html_attributes @ param_html_attributes };
    { tag = "picture"; attributes = common_html_attributes };
    { tag = "pre"; attributes = common_html_attributes };
    { tag = "progress"; attributes = common_html_attributes @ progress_html_attributes };
    { tag = "q"; attributes = common_html_attributes @ quote_html_attributes };
    { tag = "rp"; attributes = common_html_attributes };
    { tag = "rt"; attributes = common_html_attributes };
    { tag = "ruby"; attributes = common_html_attributes };
    { tag = "s"; attributes = common_html_attributes };
    { tag = "samp"; attributes = common_html_attributes };
    { tag = "script"; attributes = common_html_attributes @ script_html_attributes };
    { tag = "section"; attributes = common_html_attributes };
    { tag = "select"; attributes = common_html_attributes @ select_html_attributes };
    { tag = "slot"; attributes = common_html_attributes @ slot_html_attributes };
    { tag = "small"; attributes = common_html_attributes };
    { tag = "source"; attributes = common_html_attributes @ source_html_attributes };
    { tag = "span"; attributes = common_html_attributes };
    { tag = "strong"; attributes = common_html_attributes };
    { tag = "style"; attributes = common_html_attributes @ style_html_attributes };
    { tag = "sub"; attributes = common_html_attributes };
    { tag = "summary"; attributes = common_html_attributes };
    { tag = "sup"; attributes = common_html_attributes };
    { tag = "table"; attributes = common_html_attributes @ table_html_attributes };
    { tag = "tbody"; attributes = common_html_attributes };
    { tag = "td"; attributes = common_html_attributes @ td_html_attributes };
    { tag = "template"; attributes = common_html_attributes };
    { tag = "textarea"; attributes = common_html_attributes @ textarea_html_attributes };
    { tag = "tfoot"; attributes = common_html_attributes };
    { tag = "th"; attributes = common_html_attributes @ th_html_attributes };
    { tag = "thead"; attributes = common_html_attributes };
    { tag = "time"; attributes = common_html_attributes @ time_html_attributes };
    { tag = "title"; attributes = common_html_attributes };
    { tag = "tr"; attributes = common_html_attributes };
    { tag = "track"; attributes = common_html_attributes @ track_html_attributes };
    { tag = "u"; attributes = common_html_attributes };
    { tag = "ul"; attributes = common_html_attributes };
    { tag = "var"; attributes = common_html_attributes };
    { tag = "video"; attributes = common_html_attributes @ video_html_attributes };
    { tag = "wbr"; attributes = common_html_attributes };
    { tag = "webview"; attributes = common_html_attributes @ web_view_html_attributes };
  ]

let common_svg_attributes = SVG.attributes @ react_attributes @ global_event_handlers @ aria_attributes

let fe_convolve_matrix_attributes = [ Attribute { name = "preserveAlpha"; jsx_name = "preserve_alpha"; reason_jsx_name = "preserve_alpha"; type_ = Booleanish_string } ]

let svg_elements =
  [
    { tag = "svg"; attributes = common_svg_attributes };
    { tag = "animate"; attributes = common_svg_attributes };
    { tag = "animateMotion"; attributes = common_svg_attributes };
    { tag = "animateTransform"; attributes = common_svg_attributes };
    { tag = "circle"; attributes = common_svg_attributes };
    { tag = "clipPath"; attributes = common_svg_attributes };
    { tag = "defs"; attributes = common_svg_attributes };
    { tag = "desc"; attributes = common_svg_attributes };
    { tag = "ellipse"; attributes = common_svg_attributes };
    { tag = "feBlend"; attributes = common_svg_attributes };
    { tag = "feColorMatrix"; attributes = common_svg_attributes };
    { tag = "feComponentTransfer"; attributes = common_svg_attributes };
    { tag = "feComposite"; attributes = common_svg_attributes };
    { tag = "feConvolveMatrix"; attributes = common_svg_attributes @ fe_convolve_matrix_attributes };
    { tag = "feDiffuseLighting"; attributes = common_svg_attributes };
    { tag = "feDisplacementMap"; attributes = common_svg_attributes };
    { tag = "feDistantLight"; attributes = common_svg_attributes };
    { tag = "feDropShadow"; attributes = common_svg_attributes };
    { tag = "feFlood"; attributes = common_svg_attributes };
    { tag = "feFuncA"; attributes = common_svg_attributes };
    { tag = "feFuncB"; attributes = common_svg_attributes };
    { tag = "feFuncG"; attributes = common_svg_attributes };
    { tag = "feFuncR"; attributes = common_svg_attributes };
    { tag = "feGaussianBlur"; attributes = common_svg_attributes };
    { tag = "feImage"; attributes = common_svg_attributes };
    { tag = "feMerge"; attributes = common_svg_attributes };
    { tag = "feMergeNode"; attributes = common_svg_attributes };
    { tag = "feMorphology"; attributes = common_svg_attributes };
    { tag = "feOffset"; attributes = common_svg_attributes };
    { tag = "fePointLight"; attributes = common_svg_attributes };
    { tag = "feSpecularLighting"; attributes = common_svg_attributes };
    { tag = "feSpotLight"; attributes = common_svg_attributes };
    { tag = "feTile"; attributes = common_svg_attributes };
    { tag = "feTurbulence"; attributes = common_svg_attributes };
    { tag = "filter"; attributes = common_svg_attributes };
    { tag = "foreignObject"; attributes = common_svg_attributes };
    { tag = "g"; attributes = common_svg_attributes };
    { tag = "image"; attributes = common_svg_attributes };
    { tag = "line"; attributes = common_svg_attributes };
    { tag = "linearGradient"; attributes = common_svg_attributes };
    { tag = "marker"; attributes = common_svg_attributes };
    { tag = "mask"; attributes = common_svg_attributes };
    { tag = "metadata"; attributes = common_svg_attributes };
    { tag = "mpath"; attributes = common_svg_attributes };
    { tag = "path"; attributes = common_svg_attributes };
    { tag = "pattern"; attributes = common_svg_attributes };
    { tag = "polygon"; attributes = common_svg_attributes };
    { tag = "polyline"; attributes = common_svg_attributes };
    { tag = "radialGradient"; attributes = common_svg_attributes };
    { tag = "rect"; attributes = common_svg_attributes };
    { tag = "stop"; attributes = common_svg_attributes };
    { tag = "switch"; attributes = common_svg_attributes };
    { tag = "symbol"; attributes = common_svg_attributes };
    { tag = "text"; attributes = common_svg_attributes };
    { tag = "textPath"; attributes = common_svg_attributes };
    { tag = "tspan"; attributes = common_svg_attributes };
    { tag = "use"; attributes = common_svg_attributes };
    { tag = "view"; attributes = common_svg_attributes };
  ]
[@@@ocamlformat "enable"]

let dom_attributes = common_svg_attributes @ common_html_attributes
let elements = svg_elements @ html_elements

let get_reason_jsx_name = function
  | Attribute { reason_jsx_name; _ } -> reason_jsx_name
  | Event { jsx_name; _ } -> jsx_name

let get_jsx_name = function Attribute { jsx_name; _ } -> jsx_name | Event { jsx_name; _ } -> jsx_name
let dom_prop_names = List.map get_jsx_name dom_attributes

type errors = [ `Element_not_found | `Attribute_not_found ]

let get_attributes tag =
  List.find_opt (fun element -> element.tag = tag) elements |> Option.to_result ~none:`Element_not_found

let is_data_attribute = String.starts_with ~prefix:"data"
let snake_case_to_kebab_case = String.map (function '_' -> '-' | c -> c)

let find_by_jsx_name ~tag name =
  let jsx_name = name in
  let by_reason_name p = get_reason_jsx_name p = jsx_name in
  if is_data_attribute jsx_name then
    let name = snake_case_to_kebab_case jsx_name in
    Ok (Attribute { name; jsx_name; reason_jsx_name = jsx_name; type_ = String })
  else
    match get_attributes tag with
    | Ok { attributes; _ } -> (
        match List.find_opt by_reason_name attributes with Some p -> Ok p | None -> Error `Attribute_not_found)
    | Error err -> Error err

module Levenshtein = struct
  (* Levenshtein distance from
     https://rosettacode.org/wiki/Levenshtein_distance *)
  let minimum a b c = min a (min b c)

  let distance s t =
    let first = String.length s and second = String.length t in
    let matrix = Array.make_matrix (first + 1) (second + 1) 0 in
    for i = 0 to first do
      matrix.(i).(0) <- i
    done;
    for j = 0 to second do
      matrix.(0).(j) <- j
    done;
    for j = 1 to second do
      for i = 1 to first do
        if s.[i - 1] = t.[j - 1] then matrix.(i).(j) <- matrix.(i - 1).(j - 1)
        else matrix.(i).(j) <- minimum (matrix.(i - 1).(j) + 1) (matrix.(i).(j - 1) + 1) (matrix.(i - 1).(j - 1) + 1)
      done
    done;
    matrix.(first).(second)
end

let find_closest_name invalid =
  let accumulate_distance name (best_name, best_distance) =
    let distance = Levenshtein.distance invalid name in
    match distance < best_distance with true -> (name, distance) | false -> (best_name, best_distance)
  in
  let name, distance = List.fold_right accumulate_distance dom_prop_names ("", max_int) in
  if distance > 2 then None else Some name
