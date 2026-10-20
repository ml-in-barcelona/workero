(* Rewrites [React_dom.Style.make ~foo:a ~bar:b ()] at compile time into a
   direct list of [(kebab, camel, value)] tuples, avoiding the 347-optional-arg
   calling convention overhead (~1460 words/call on stock OCaml).

   The PPX only rewrites calls where:
   - the function is literally [React_dom.Style.make] (or [Style.make] in the
     React_dom module namespace), and
   - all arguments are labelled (not optional), and
   - the final arg is [()].
   Calls that don't fit fall through to the runtime function. *)

open Ppxlib
open Ast_builder.Default

(* CamelCase -> kebab-case mapping, kept in sync with React_dom_style.ml. *)
let mapping =
  [
    ("azimuth", "azimuth");
    ("background", "background");
    ("background_attachment", "background-attachment");
    ("background_color", "background-color");
    ("background_image", "background-image");
    ("background_position", "background-position");
    ("background_repeat", "background-repeat");
    ("border", "border");
    ("border_collapse", "border-collapse");
    ("border_color", "border-color");
    ("border_spacing", "border-spacing");
    ("border_style", "border-style");
    ("border_top", "border-top");
    ("border_right", "border-right");
    ("border_bottom", "border-bottom");
    ("border_left", "border-left");
    ("border_top_color", "border-top-color");
    ("border_right_color", "border-right-color");
    ("border_bottom_color", "border-bottom-color");
    ("border_left_color", "border-left-color");
    ("border_top_style", "border-top-style");
    ("border_right_style", "border-right-style");
    ("border_bottom_style", "border-bottom-style");
    ("border_left_style", "border-left-style");
    ("border_top_width", "border-top-width");
    ("border_right_width", "border-right-width");
    ("border_bottom_width", "border-bottom-width");
    ("border_left_width", "border-left-width");
    ("border_width", "border-width");
    ("bottom", "bottom");
    ("caption_side", "caption-side");
    ("clear", "clear");
    ("color", "color");
    ("content", "content");
    ("counter_increment", "counter-increment");
    ("counter_reset", "counter-reset");
    ("cue", "cue");
    ("cue_after", "cue-after");
    ("cue_before", "cue-before");
    ("cursor", "cursor");
    ("direction", "direction");
    ("display", "display");
    ("elevation", "elevation");
    ("empty_cells", "empty-cells");
    ("float", "float");
    ("font", "font");
    ("font_family", "font-family");
    ("font_size", "font-size");
    ("font_size_adjust", "font-size-adjust");
    ("font_stretch", "font-stretch");
    ("font_style", "font-style");
    ("font_variant", "font-variant");
    ("font_weight", "font-weight");
    ("height", "height");
    ("left", "left");
    ("letter_spacing", "letter-spacing");
    ("line_height", "line-height");
    ("list_style", "list-style");
    ("list_style_image", "list-style-image");
    ("list_style_position", "list-style-position");
    ("list_style_type", "list-style-type");
    ("margin", "margin");
    ("margin_top", "margin-top");
    ("margin_right", "margin-right");
    ("margin_bottom", "margin-bottom");
    ("margin_left", "margin-left");
    ("marker_offset", "marker-offset");
    ("marks", "marks");
    ("max_height", "max-height");
    ("max_width", "max-width");
    ("min_height", "min-height");
    ("min_width", "min-width");
    ("orphans", "orphans");
    ("outline", "outline");
    ("outline_color", "outline-color");
    ("outline_style", "outline-style");
    ("outline_width", "outline-width");
    ("overflow", "overflow");
    ("overflow_x", "overflow-x");
    ("overflow_y", "overflow-y");
    ("padding", "padding");
    ("padding_top", "padding-top");
    ("padding_right", "padding-right");
    ("padding_bottom", "padding-bottom");
    ("padding_left", "padding-left");
    ("page", "page");
    ("page_break_after", "page-break-after");
    ("page_break_before", "page-break-before");
    ("page_break_inside", "page-break-inside");
    ("pause", "pause");
    ("pause_after", "pause-after");
    ("pause_before", "pause-before");
    ("pitch", "pitch");
    ("pitch_range", "pitch-range");
    ("play_during", "play-during");
    ("position", "position");
    ("quotes", "quotes");
    ("richness", "richness");
    ("right", "right");
    ("size", "size");
    ("speak", "speak");
    ("speak_header", "speak-header");
    ("speak_numeral", "speak-numeral");
    ("speak_punctuation", "speak-punctuation");
    ("speech_rate", "speech-rate");
    ("stress", "stress");
    ("table_layout", "table-layout");
    ("text_align", "text-align");
    ("text_decoration", "text-decoration");
    ("text_indent", "text-indent");
    ("text_shadow", "text-shadow");
    ("text_transform", "text-transform");
    ("top", "top");
    ("unicode_bidi", "unicode-bidi");
    ("vertical_align", "vertical-align");
    ("visibility", "visibility");
    ("voice_family", "voice-family");
    ("volume", "volume");
    ("white_space", "white-space");
    ("widows", "widows");
    ("width", "width");
    ("word_spacing", "word-spacing");
    ("z_index", "z-index");
    ("opacity", "opacity");
    ("background_origin", "background-origin");
    ("background_size", "background-size");
    ("background_clip", "background-clip");
    ("border_radius", "border-radius");
    ("border_top_left_radius", "border-top-left-radius");
    ("border_top_right_radius", "border-top-right-radius");
    ("border_bottom_left_radius", "border-bottom-left-radius");
    ("border_bottom_right_radius", "border-bottom-right-radius");
    ("border_image", "border-image");
    ("border_image_source", "border-image-source");
    ("border_image_slice", "border-image-slice");
    ("border_image_width", "border-image-width");
    ("border_image_outset", "border-image-outset");
    ("border_image_repeat", "border-image-repeat");
    ("box_shadow", "box-shadow");
    ("columns", "columns");
    ("column_count", "column-count");
    ("column_fill", "column-fill");
    ("column_gap", "column-gap");
    ("column_rule", "column-rule");
    ("column_rule_color", "column-rule-color");
    ("column_rule_style", "column-rule-style");
    ("column_rule_width", "column-rule-width");
    ("column_span", "column-span");
    ("column_width", "column-width");
    ("break_after", "break-after");
    ("break_before", "break-before");
    ("break_inside", "break-inside");
    ("rest", "rest");
    ("rest_after", "rest-after");
    ("rest_before", "rest-before");
    ("speak_as", "speak-as");
    ("voice_balance", "voice-balance");
    ("voice_duration", "voice-duration");
    ("voice_pitch", "voice-pitch");
    ("voice_range", "voice-range");
    ("voice_rate", "voice-rate");
    ("voice_stress", "voice-stress");
    ("voice_volume", "voice-volume");
    ("object_fit", "object-fit");
    ("object_position", "object-position");
    ("image_resolution", "image-resolution");
    ("image_orientation", "image-orientation");
    ("align_content", "align-content");
    ("align_items", "align-items");
    ("align_self", "align-self");
    ("flex", "flex");
    ("flex_basis", "flex-basis");
    ("flex_direction", "flex-direction");
    ("flex_flow", "flex-flow");
    ("flex_grow", "flex-grow");
    ("flex_shrink", "flex-shrink");
    ("flex_wrap", "flex-wrap");
    ("justify_content", "justify-content");
    ("order", "order");
    ("text_decoration_color", "text-decoration-color");
    ("text_decoration_line", "text-decoration-line");
    ("text_decoration_skip", "text-decoration-skip");
    ("text_decoration_style", "text-decoration-style");
    ("text_emphasis", "text-emphasis");
    ("text_emphasis_color", "text-emphasis-color");
    ("text_emphasis_position", "text-emphasis-position");
    ("text_emphasis_style", "text-emphasis-style");
    ("text_underline_position", "text-underline-position");
    ("font_feature_settings", "font-feature-settings");
    ("font_kerning", "font-kerning");
    ("font_language_override", "font-language-override");
    ("font_synthesis", "font-synthesis");
    ("fornt_variant_alternates", "fornt-variant-alternates");
    ("font_variant_caps", "font-variant-caps");
    ("font_variant_east_asian", "font-variant-east-asian");
    ("font_variant_ligatures", "font-variant-ligatures");
    ("font_variant_numeric", "font-variant-numeric");
    ("font_variant_position", "font-variant-position");
    ("all", "all");
    ("text_combine_upright", "text-combine-upright");
    ("text_orientation", "text-orientation");
    ("writing_mode", "writing-mode");
    ("shape_image_threshold", "shape-image-threshold");
    ("shape_margin", "shape-margin");
    ("shape_outside", "shape-outside");
    ("mask", "mask");
    ("mask_border", "mask-border");
    ("mask_border_mode", "mask-border-mode");
    ("mask_border_outset", "mask-border-outset");
    ("mask_border_repeat", "mask-border-repeat");
    ("mask_border_slice", "mask-border-slice");
    ("mask_border_source", "mask-border-source");
    ("mask_border_width", "mask-border-width");
    ("mask_clip", "mask-clip");
    ("mask_composite", "mask-composite");
    ("mask_image", "mask-image");
    ("mask_mode", "mask-mode");
    ("mask_origin", "mask-origin");
    ("mask_position", "mask-position");
    ("mask_repeat", "mask-repeat");
    ("mask_size", "mask-size");
    ("mask_type", "mask-type");
    ("background_blend_mode", "background-blend-mode");
    ("isolation", "isolation");
    ("mix_blend_mode", "mix-blend-mode");
    ("box_decoration_break", "box-decoration-break");
    ("box_sizing", "box-sizing");
    ("caret_color", "caret-color");
    ("nav_down", "nav-down");
    ("nav_left", "nav-left");
    ("nav_right", "nav-right");
    ("nav_up", "nav-up");
    ("outline_offset", "outline-offset");
    ("resize", "resize");
    ("text_overflow", "text-overflow");
    ("grid", "grid");
    ("grid_area", "grid-area");
    ("grid_auto_columns", "grid-auto-columns");
    ("grid_auto_flow", "grid-auto-flow");
    ("grid_auto_rows", "grid-auto-rows");
    ("grid_column", "grid-column");
    ("grid_column_end", "grid-column-end");
    ("grid_column_gap", "grid-column-gap");
    ("grid_column_start", "grid-column-start");
    ("grid_gap", "grid-gap");
    ("grid_row", "grid-row");
    ("grid_row_end", "grid-row-end");
    ("grid_row_gap", "grid-row-gap");
    ("grid_row_start", "grid-row-start");
    ("grid_template", "grid-template");
    ("grid_template_areas", "grid-template-areas");
    ("grid_template_columns", "grid-template-columns");
    ("grid_template_rows", "grid-template-rows");
    ("will_change", "will-change");
    ("hanging_punctuation", "hanging-punctuation");
    ("hyphens", "hyphens");
    ("line_break", "line-break");
    ("overflow_wrap", "overflow-wrap");
    ("tab_size", "tab-size");
    ("text_align_last", "text-align-last");
    ("text_justify", "text-justify");
    ("word_break", "word-break");
    ("word_wrap", "word-wrap");
    ("animation", "animation");
    ("animation_delay", "animation-delay");
    ("animation_direction", "animation-direction");
    ("animation_duration", "animation-duration");
    ("animation_fill_mode", "animation-fill-mode");
    ("animation_iteration_count", "animation-iteration-count");
    ("animation_name", "animation-name");
    ("animation_play_state", "animation-play-state");
    ("animation_timing_function", "animation-timing-function");
    ("transition", "transition");
    ("transition_delay", "transition-delay");
    ("transition_duration", "transition-duration");
    ("transition_property", "transition-property");
    ("transition_timing_function", "transition-timing-function");
    ("backface_visibility", "backface-visibility");
    ("perspective", "perspective");
    ("perspective_origin", "perspective-origin");
    ("transform", "transform");
    ("transform_origin", "transform-origin");
    ("transform_style", "transform-style");
    ("justify_items", "justify-items");
    ("justify_self", "justify-self");
    ("place_content", "place-content");
    ("place_items", "place-items");
    ("place_self", "place-self");
    ("appearance", "appearance");
    ("caret", "caret");
    ("caret_animation", "caret-animation");
    ("caret_shape", "caret-shape");
    ("user_select", "user-select");
    ("max_lines", "max-lines");
    ("marquee_direction", "marquee-direction");
    ("marquee_loop", "marquee-loop");
    ("marquee_speed", "marquee-speed");
    ("marquee_style", "marquee-style");
    ("overflow_style", "overflow-style");
    ("rotation", "rotation");
    ("rotation_point", "rotation-point");
    ("alignment_baseline", "alignment-baseline");
    ("baseline_shift", "baseline-shift");
    ("clip", "clip");
    ("clip_path", "clip-path");
    ("clip_rule", "clip-rule");
    ("color_interpolation", "color-interpolation");
    ("color_interpolation_filters", "color-interpolation-filters");
    ("color_profile", "color-profile");
    ("color_rendering", "color-rendering");
    ("dominant_baseline", "dominant-baseline");
    ("fill", "fill");
    ("fill_opacity", "fill-opacity");
    ("fill_rule", "fill-rule");
    ("filter", "filter");
    ("flood_color", "flood-color");
    ("flood_opacity", "flood-opacity");
    ("glyph_orientation_horizontal", "glyph-orientation-horizontal");
    ("glyph_orientation_vertical", "glyph-orientation-vertical");
    ("image_rendering", "image-rendering");
    ("kerning", "kerning");
    ("lighting_color", "lighting-color");
    ("marker_end", "marker-end");
    ("marker_mid", "marker-mid");
    ("marker_start", "marker-start");
    ("pointer_events", "pointer-events");
    ("shape_rendering", "shape-rendering");
    ("stop_color", "stop-color");
    ("stop_opacity", "stop-opacity");
    ("stroke", "stroke");
    ("stroke_dasharray", "stroke-dasharray");
    ("stroke_dashoffset", "stroke-dashoffset");
    ("stroke_linecap", "stroke-linecap");
    ("stroke_linejoin", "stroke-linejoin");
    ("stroke_miterlimit", "stroke-miterlimit");
    ("stroke_opacity", "stroke-opacity");
    ("stroke_width", "stroke-width");
    ("text_anchor", "text-anchor");
    ("text_rendering", "text-rendering");
    ("ruby_align", "ruby-align");
    ("ruby_merge", "ruby-merge");
    ("ruby_position", "ruby-position");
  ]

(* Assoc of camel -> (kebab, signature_index). *)
let indexed_mapping = List.mapi (fun i (camel, kebab) -> (camel, (kebab, i))) mapping
let find_camel camel = List.assoc_opt camel indexed_mapping

(* Returns true if [longident] is [React_dom.Style.make] (possibly prefixed). *)
let is_style_make_ident = function
  | Ldot (Ldot (Lident "React_dom", "Style"), "make") -> true
  | Ldot (Lident "Style", "make") -> true (* used inside React_dom module *)
  | _ -> false

(* Attempt to rewrite a call [React_dom.Style.make ~foo:a ~bar:b ()] to a direct
   list expression. Returns [Some new_expr] on success, [None] otherwise.

   The final arg must be [()] (Nolabel, unit), and there must be no optional
   args and no unknown label names.

   The output list must match the runtime order produced by [Style.make]:
   signature order (the body prepends in signature order and reverses at the
   end). Signature order is also the JS object key order melange produces for
   reason-react's [React_dom.Style.make], which react-dom preserves in both
   inline style output and the Flight payload. *)
let try_rewrite_call ~loc:_ args =
  let rec collect acc = function
    | [] -> None (* missing the final unit *)
    | [ (Nolabel, { pexp_desc = Pexp_construct ({ txt = Lident "()"; _ }, None); _ }) ] -> Some acc
    | (Labelled name, expr) :: rest -> (
        match find_camel name with
        | Some (kebab, idx) -> collect ((idx, name, kebab, expr) :: acc) rest
        | None ->
            (* unknown style name — fall back *)
            None)
    | (Optional _, _) :: _ -> None (* optional arg — fall back *)
    | (Nolabel, _) :: _ -> None (* unexpected positional — fall back *)
  in
  match collect [] args with
  | None -> None
  | Some entries ->
      (* Sort by signature index ascending, matching the runtime [make]'s
         output order. *)
      let sorted = List.sort (fun (i, _, _, _) (j, _, _, _) -> Int.compare i j) entries in
      let loc = Location.none in
      let list_expr =
        List.fold_right
          (fun (_, camel, kebab, expr) acc ->
            let loc = expr.pexp_loc in
            [%expr ([%e estring ~loc kebab], [%e estring ~loc camel], [%e expr]) :: [%e acc]])
          sorted
          [%expr ([] : (string * string * string) list)]
      in
      Some [%expr ([%e list_expr] : React_dom.Style.t)]

(* Top-level rewriter: looks at any [Pexp_apply] and rewrites eligible ones. *)
let rewrite_expression expr =
  match expr.pexp_desc with
  | Pexp_apply ({ pexp_desc = Pexp_ident { txt; _ }; _ }, args) when is_style_make_ident txt -> (
      match try_rewrite_call ~loc:expr.pexp_loc args with Some new_expr -> new_expr | None -> expr)
  | _ -> expr
