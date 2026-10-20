type t = (string * string * string) list

[@@@ocamlformat "disable"]

let make
  ?(azimuth : string option)
  ?(background : string option)
  ?(background_attachment : string option)
  ?(background_color : string option)
  ?(background_image : string option)
  ?(background_position : string option)
  ?(background_repeat : string option)
  ?(border : string option)
  ?(border_collapse : string option)
  ?(border_color : string option)
  ?(border_spacing : string option)
  ?(border_style : string option)
  ?(border_top : string option)
  ?(border_right : string option)
  ?(border_bottom : string option)
  ?(border_left : string option)
  ?(border_top_color : string option)
  ?(border_right_color : string option)
  ?(border_bottom_color : string option)
  ?(border_left_color : string option)
  ?(border_top_style : string option)
  ?(border_right_style : string option)
  ?(border_bottom_style : string option)
  ?(border_left_style : string option)
  ?(border_top_width : string option)
  ?(border_right_width : string option)
  ?(border_bottom_width : string option)
  ?(border_left_width : string option)
  ?(border_width : string option)
  ?(bottom : string option)
  ?(caption_side : string option)
  ?(clear : string option)
  ?(color : string option)
  ?(content : string option)
  ?(counter_increment : string option)
  ?(counter_reset : string option)
  ?(cue : string option)
  ?(cue_after : string option)
  ?(cue_before : string option)
  ?(cursor : string option)
  ?(direction : string option)
  ?(display : string option)
  ?(elevation : string option)
  ?(empty_cells : string option)
  ?(float : string option)
  ?(font : string option)
  ?(font_family : string option)
  ?(font_size : string option)
  ?(font_size_adjust : string option)
  ?(font_stretch : string option)
  ?(font_style : string option)
  ?(font_variant : string option)
  ?(font_weight : string option)
  ?(height : string option)
  ?(left : string option)
  ?(letter_spacing : string option)
  ?(line_height : string option)
  ?(list_style : string option)
  ?(list_style_image : string option)
  ?(list_style_position : string option)
  ?(list_style_type : string option)
  ?(margin : string option)
  ?(margin_top : string option)
  ?(margin_right : string option)
  ?(margin_bottom : string option)
  ?(margin_left : string option)
  ?(marker_offset : string option)
  ?(marks : string option)
  ?(max_height : string option)
  ?(max_width : string option)
  ?(min_height : string option)
  ?(min_width : string option)
  ?(orphans : string option)
  ?(outline : string option)
  ?(outline_color : string option)
  ?(outline_style : string option)
  ?(outline_width : string option)
  ?(overflow : string option)
  ?(overflow_x : string option)
  ?(overflow_y : string option)
  ?(padding : string option)
  ?(padding_top : string option)
  ?(padding_right : string option)
  ?(padding_bottom : string option)
  ?(padding_left : string option)
  ?(page : string option)
  ?(page_break_after : string option)
  ?(page_break_before : string option)
  ?(page_break_inside : string option)
  ?(pause : string option)
  ?(pause_after : string option)
  ?(pause_before : string option)
  ?(pitch : string option)
  ?(pitch_range : string option)
  ?(play_during : string option)
  ?(position : string option)
  ?(quotes : string option)
  ?(richness : string option)
  ?(right : string option)
  ?(size : string option)
  ?(speak : string option)
  ?(speak_header : string option)
  ?(speak_numeral : string option)
  ?(speak_punctuation : string option)
  ?(speech_rate : string option)
  ?(stress : string option)
  ?(table_layout : string option)
  ?(text_align : string option)
  ?(text_decoration : string option)
  ?(text_indent : string option)
  ?(text_shadow : string option)
  ?(text_transform : string option)
  ?(top : string option)
  ?(unicode_bidi : string option)
  ?(vertical_align : string option)
  ?(visibility : string option)
  ?(voice_family : string option)
  ?(volume : string option)
  ?(white_space : string option)
  ?(widows : string option)
  ?(width : string option)
  ?(word_spacing : string option)
  ?(z_index : string option)
  ?(opacity : string option)
  ?(background_origin : string option)
  ?(background_size : string option)
  ?(background_clip : string option)
  ?(border_radius : string option)
  ?(border_top_left_radius : string option)
  ?(border_top_right_radius : string option)
  ?(border_bottom_left_radius : string option)
  ?(border_bottom_right_radius : string option)
  ?(border_image : string option)
  ?(border_image_source : string option)
  ?(border_image_slice : string option)
  ?(border_image_width : string option)
  ?(border_image_outset : string option)
  ?(border_image_repeat : string option)
  ?(box_shadow : string option)
  ?(columns : string option)
  ?(column_count : string option)
  ?(column_fill : string option)
  ?(column_gap : string option)
  ?(column_rule : string option)
  ?(column_rule_color : string option)
  ?(column_rule_style : string option)
  ?(column_rule_width : string option)
  ?(column_span : string option)
  ?(column_width : string option)
  ?(break_after : string option)
  ?(break_before : string option)
  ?(break_inside : string option)
  ?(rest : string option)
  ?(rest_after : string option)
  ?(rest_before : string option)
  ?(speak_as : string option)
  ?(voice_balance : string option)
  ?(voice_duration : string option)
  ?(voice_pitch : string option)
  ?(voice_range : string option)
  ?(voice_rate : string option)
  ?(voice_stress : string option)
  ?(voice_volume : string option)
  ?(object_fit : string option)
  ?(object_position : string option)
  ?(image_resolution : string option)
  ?(image_orientation : string option)
  ?(align_content : string option)
  ?(align_items : string option)
  ?(align_self : string option)
  ?(flex : string option)
  ?(flex_basis : string option)
  ?(flex_direction : string option)
  ?(flex_flow : string option)
  ?(flex_grow : string option)
  ?(flex_shrink : string option)
  ?(flex_wrap : string option)
  ?(justify_content : string option)
  ?(order : string option)
  ?(text_decoration_color : string option)
  ?(text_decoration_line : string option)
  ?(text_decoration_skip : string option)
  ?(text_decoration_style : string option)
  ?(text_emphasis : string option)
  ?(text_emphasis_color : string option)
  ?(text_emphasis_position : string option)
  ?(text_emphasis_style : string option)
  ?(text_underline_position : string option)
  ?(font_feature_settings : string option)
  ?(font_kerning : string option)
  ?(font_language_override : string option)
  ?(font_synthesis : string option)
  ?(forntVariantAlternates : string option)
  ?(font_variant_caps : string option)
  ?(font_variant_east_asian : string option)
  ?(font_variant_ligatures : string option)
  ?(font_variant_numeric : string option)
  ?(font_variant_position : string option)
  ?(all : string option)
  ?(text_combine_upright : string option)
  ?(text_orientation : string option)
  ?(writing_mode : string option)
  ?(shape_image_threshold : string option)
  ?(shape_margin : string option)
  ?(shape_outside : string option)
  ?(mask : string option)
  ?(mask_border : string option)
  ?(mask_border_mode : string option)
  ?(mask_border_outset : string option)
  ?(mask_border_repeat : string option)
  ?(mask_border_slice : string option)
  ?(mask_border_source : string option)
  ?(mask_border_width : string option)
  ?(mask_clip : string option)
  ?(mask_composite : string option)
  ?(mask_image : string option)
  ?(mask_mode : string option)
  ?(mask_origin : string option)
  ?(mask_position : string option)
  ?(mask_repeat : string option)
  ?(mask_size : string option)
  ?(mask_type : string option)
  ?(background_blend_mode : string option)
  ?(isolation : string option)
  ?(mix_blend_mode : string option)
  ?(box_decoration_break : string option)
  ?(box_sizing : string option)
  ?(caret_color : string option)
  ?(nav_down : string option)
  ?(nav_left : string option)
  ?(nav_right : string option)
  ?(nav_up : string option)
  ?(outline_offset : string option)
  ?(resize : string option)
  ?(text_overflow : string option)
  ?(grid : string option)
  ?(grid_area : string option)
  ?(grid_auto_columns : string option)
  ?(grid_auto_flow : string option)
  ?(grid_auto_rows : string option)
  ?(grid_column : string option)
  ?(grid_column_end : string option)
  ?(grid_column_gap : string option)
  ?(grid_column_start : string option)
  ?(grid_gap : string option)
  ?(grid_row : string option)
  ?(grid_row_end : string option)
  ?(grid_row_gap : string option)
  ?(grid_row_start : string option)
  ?(grid_template : string option)
  ?(grid_template_areas : string option)
  ?(grid_template_columns : string option)
  ?(grid_template_rows : string option)
  ?(will_change : string option)
  ?(hanging_punctuation : string option)
  ?(hyphens : string option)
  ?(line_break : string option)
  ?(overflow_wrap : string option)
  ?(tab_size : string option)
  ?(text_align_last : string option)
  ?(text_justify : string option)
  ?(word_break : string option)
  ?(word_wrap : string option)
  ?(animation : string option)
  ?(animation_delay : string option)
  ?(animation_direction : string option)
  ?(animation_duration : string option)
  ?(animation_fill_mode : string option)
  ?(animation_iteration_count : string option)
  ?(animation_name : string option)
  ?(animation_play_state : string option)
  ?(animation_timing_function : string option)
  ?(transition : string option)
  ?(transition_delay : string option)
  ?(transition_duration : string option)
  ?(transition_property : string option)
  ?(transition_timing_function : string option)
  ?(backface_visibility : string option)
  ?(perspective : string option)
  ?(perspective_origin : string option)
  ?(transform : string option)
  ?(transform_origin : string option)
  ?(transform_style : string option)
  ?(justify_items : string option)
  ?(justify_self : string option)
  ?(place_content : string option)
  ?(place_items : string option)
  ?(place_self : string option)
  ?(appearance : string option)
  ?(caret : string option)
  ?(caret_animation : string option)
  ?(caret_shape : string option)
  ?(user_select : string option)
  ?(max_lines : string option)
  ?(marquee_direction : string option)
  ?(marquee_loop : string option)
  ?(marquee_speed : string option)
  ?(marquee_style : string option)
  ?(overflow_style : string option)
  ?(rotation : string option)
  ?(rotation_point : string option)
  ?(alignment_baseline : string option)
  ?(baseline_shift : string option)
  ?(clip : string option)
  ?(clip_path : string option)
  ?(clip_rule : string option)
  ?(color_interpolation : string option)
  ?(color_interpolation_filters : string option)
  ?(color_profile : string option)
  ?(color_rendering : string option)
  ?(dominant_baseline : string option)
  ?(fill : string option)
  ?(fill_opacity : string option)
  ?(fill_rule : string option)
  ?(filter : string option)
  ?(flood_color : string option)
  ?(flood_opacity : string option)
  ?(glyph_orientation_horizontal : string option)
  ?(glyph_orientation_vertical : string option)
  ?(image_rendering : string option)
  ?(kerning : string option)
  ?(lighting_color : string option)
  ?(marker_end : string option)
  ?(marker_mid : string option)
  ?(marker_start : string option)
  ?(pointer_events : string option)
  ?(shape_rendering : string option)
  ?(stop_color : string option)
  ?(stop_opacity : string option)
  ?(stroke : string option)
  ?(stroke_dasharray : string option)
  ?(stroke_dashoffset : string option)
  ?(stroke_linecap : string option)
  ?(stroke_linejoin : string option)
  ?(stroke_miterlimit : string option)
  ?(stroke_opacity : string option)
  ?(stroke_width : string option)
  ?(text_anchor : string option)
  ?(text_rendering : string option)
  ?(ruby_align : string option)
  ?(ruby_merge : string option)
  ?(ruby_position : string option)
  () =
  (*
     The order of addition matters since it will need to be the same order as
  the JS object defined in https://github.com/reasonml/reason-react/blob/3327dc214905c4b2863b19807aaac375633645cf/src/dOMStyle.re

  The following shell script can be run from the reason-react repository to generate the calls to "add" below:

  for style in $(cat src/dOMStyle.re | grep "~" | sed 's/.*\~\([^:]*\):.*/\1/'); do
    dashed=$(echo "$style" | sed 's/\([A-Z]\)/-\L\1/g')
    echo "|> add \"$dashed\" $style"
  done
  *)

  let acc = [] in
  let acc = match azimuth with Some v -> ("azimuth", "azimuth", v) :: acc | None -> acc in
  let acc = match background with Some v -> ("background", "background", v) :: acc | None -> acc in
  let acc = match background_attachment with Some v -> ("background-attachment", "background_attachment", v) :: acc | None -> acc in
  let acc = match background_color with Some v -> ("background-color", "background_color", v) :: acc | None -> acc in
  let acc = match background_image with Some v -> ("background-image", "background_image", v) :: acc | None -> acc in
  let acc = match background_position with Some v -> ("background-position", "background_position", v) :: acc | None -> acc in
  let acc = match background_repeat with Some v -> ("background-repeat", "background_repeat", v) :: acc | None -> acc in
  let acc = match border with Some v -> ("border", "border", v) :: acc | None -> acc in
  let acc = match border_collapse with Some v -> ("border-collapse", "border_collapse", v) :: acc | None -> acc in
  let acc = match border_color with Some v -> ("border-color", "border_color", v) :: acc | None -> acc in
  let acc = match border_spacing with Some v -> ("border-spacing", "border_spacing", v) :: acc | None -> acc in
  let acc = match border_style with Some v -> ("border-style", "border_style", v) :: acc | None -> acc in
  let acc = match border_top with Some v -> ("border-top", "border_top", v) :: acc | None -> acc in
  let acc = match border_right with Some v -> ("border-right", "border_right", v) :: acc | None -> acc in
  let acc = match border_bottom with Some v -> ("border-bottom", "border_bottom", v) :: acc | None -> acc in
  let acc = match border_left with Some v -> ("border-left", "border_left", v) :: acc | None -> acc in
  let acc = match border_top_color with Some v -> ("border-top-color", "border_top_color", v) :: acc | None -> acc in
  let acc = match border_right_color with Some v -> ("border-right-color", "border_right_color", v) :: acc | None -> acc in
  let acc = match border_bottom_color with Some v -> ("border-bottom-color", "border_bottom_color", v) :: acc | None -> acc in
  let acc = match border_left_color with Some v -> ("border-left-color", "border_left_color", v) :: acc | None -> acc in
  let acc = match border_top_style with Some v -> ("border-top-style", "border_top_style", v) :: acc | None -> acc in
  let acc = match border_right_style with Some v -> ("border-right-style", "border_right_style", v) :: acc | None -> acc in
  let acc = match border_bottom_style with Some v -> ("border-bottom-style", "border_bottom_style", v) :: acc | None -> acc in
  let acc = match border_left_style with Some v -> ("border-left-style", "border_left_style", v) :: acc | None -> acc in
  let acc = match border_top_width with Some v -> ("border-top-width", "border_top_width", v) :: acc | None -> acc in
  let acc = match border_right_width with Some v -> ("border-right-width", "border_right_width", v) :: acc | None -> acc in
  let acc = match border_bottom_width with Some v -> ("border-bottom-width", "border_bottom_width", v) :: acc | None -> acc in
  let acc = match border_left_width with Some v -> ("border-left-width", "border_left_width", v) :: acc | None -> acc in
  let acc = match border_width with Some v -> ("border-width", "border_width", v) :: acc | None -> acc in
  let acc = match bottom with Some v -> ("bottom", "bottom", v) :: acc | None -> acc in
  let acc = match caption_side with Some v -> ("caption-side", "caption_side", v) :: acc | None -> acc in
  let acc = match clear with Some v -> ("clear", "clear", v) :: acc | None -> acc in
  let acc = match clip with Some v -> ("clip", "clip", v) :: acc | None -> acc in
  let acc = match color with Some v -> ("color", "color", v) :: acc | None -> acc in
  let acc = match content with Some v -> ("content", "content", v) :: acc | None -> acc in
  let acc = match counter_increment with Some v -> ("counter-increment", "counter_increment", v) :: acc | None -> acc in
  let acc = match counter_reset with Some v -> ("counter-reset", "counter_reset", v) :: acc | None -> acc in
  let acc = match cue with Some v -> ("cue", "cue", v) :: acc | None -> acc in
  let acc = match cue_after with Some v -> ("cue-after", "cue_after", v) :: acc | None -> acc in
  let acc = match cue_before with Some v -> ("cue-before", "cue_before", v) :: acc | None -> acc in
  let acc = match cursor with Some v -> ("cursor", "cursor", v) :: acc | None -> acc in
  let acc = match direction with Some v -> ("direction", "direction", v) :: acc | None -> acc in
  let acc = match display with Some v -> ("display", "display", v) :: acc | None -> acc in
  let acc = match elevation with Some v -> ("elevation", "elevation", v) :: acc | None -> acc in
  let acc = match empty_cells with Some v -> ("empty-cells", "empty_cells", v) :: acc | None -> acc in
  let acc = match float with Some v -> ("float", "float", v) :: acc | None -> acc in
  let acc = match font with Some v -> ("font", "font", v) :: acc | None -> acc in
  let acc = match font_family with Some v -> ("font-family", "font_family", v) :: acc | None -> acc in
  let acc = match font_size with Some v -> ("font-size", "font_size", v) :: acc | None -> acc in
  let acc = match font_size_adjust with Some v -> ("font-size-adjust", "font_size_adjust", v) :: acc | None -> acc in
  let acc = match font_stretch with Some v -> ("font-stretch", "font_stretch", v) :: acc | None -> acc in
  let acc = match font_style with Some v -> ("font-style", "font_style", v) :: acc | None -> acc in
  let acc = match font_variant with Some v -> ("font-variant", "font_variant", v) :: acc | None -> acc in
  let acc = match font_weight with Some v -> ("font-weight", "font_weight", v) :: acc | None -> acc in
  let acc = match height with Some v -> ("height", "height", v) :: acc | None -> acc in
  let acc = match left with Some v -> ("left", "left", v) :: acc | None -> acc in
  let acc = match letter_spacing with Some v -> ("letter-spacing", "letter_spacing", v) :: acc | None -> acc in
  let acc = match line_height with Some v -> ("line-height", "line_height", v) :: acc | None -> acc in
  let acc = match list_style with Some v -> ("list-style", "list_style", v) :: acc | None -> acc in
  let acc = match list_style_image with Some v -> ("list-style-image", "list_style_image", v) :: acc | None -> acc in
  let acc = match list_style_position with Some v -> ("list-style-position", "list_style_position", v) :: acc | None -> acc in
  let acc = match list_style_type with Some v -> ("list-style-type", "list_style_type", v) :: acc | None -> acc in
  let acc = match margin with Some v -> ("margin", "margin", v) :: acc | None -> acc in
  let acc = match margin_top with Some v -> ("margin-top", "margin_top", v) :: acc | None -> acc in
  let acc = match margin_right with Some v -> ("margin-right", "margin_right", v) :: acc | None -> acc in
  let acc = match margin_bottom with Some v -> ("margin-bottom", "margin_bottom", v) :: acc | None -> acc in
  let acc = match margin_left with Some v -> ("margin-left", "margin_left", v) :: acc | None -> acc in
  let acc = match marker_offset with Some v -> ("marker-offset", "marker_offset", v) :: acc | None -> acc in
  let acc = match marks with Some v -> ("marks", "marks", v) :: acc | None -> acc in
  let acc = match max_height with Some v -> ("max-height", "max_height", v) :: acc | None -> acc in
  let acc = match max_width with Some v -> ("max-width", "max_width", v) :: acc | None -> acc in
  let acc = match min_height with Some v -> ("min-height", "min_height", v) :: acc | None -> acc in
  let acc = match min_width with Some v -> ("min-width", "min_width", v) :: acc | None -> acc in
  let acc = match orphans with Some v -> ("orphans", "orphans", v) :: acc | None -> acc in
  let acc = match outline with Some v -> ("outline", "outline", v) :: acc | None -> acc in
  let acc = match outline_color with Some v -> ("outline-color", "outline_color", v) :: acc | None -> acc in
  let acc = match outline_style with Some v -> ("outline-style", "outline_style", v) :: acc | None -> acc in
  let acc = match outline_width with Some v -> ("outline-width", "outline_width", v) :: acc | None -> acc in
  let acc = match overflow with Some v -> ("overflow", "overflow", v) :: acc | None -> acc in
  let acc = match overflow_x with Some v -> ("overflow-x", "overflow_x", v) :: acc | None -> acc in
  let acc = match overflow_y with Some v -> ("overflow-y", "overflow_y", v) :: acc | None -> acc in
  let acc = match padding with Some v -> ("padding", "padding", v) :: acc | None -> acc in
  let acc = match padding_top with Some v -> ("padding-top", "padding_top", v) :: acc | None -> acc in
  let acc = match padding_right with Some v -> ("padding-right", "padding_right", v) :: acc | None -> acc in
  let acc = match padding_bottom with Some v -> ("padding-bottom", "padding_bottom", v) :: acc | None -> acc in
  let acc = match padding_left with Some v -> ("padding-left", "padding_left", v) :: acc | None -> acc in
  let acc = match page with Some v -> ("page", "page", v) :: acc | None -> acc in
  let acc = match page_break_after with Some v -> ("page-break-after", "page_break_after", v) :: acc | None -> acc in
  let acc = match page_break_before with Some v -> ("page-break-before", "page_break_before", v) :: acc | None -> acc in
  let acc = match page_break_inside with Some v -> ("page-break-inside", "page_break_inside", v) :: acc | None -> acc in
  let acc = match pause with Some v -> ("pause", "pause", v) :: acc | None -> acc in
  let acc = match pause_after with Some v -> ("pause-after", "pause_after", v) :: acc | None -> acc in
  let acc = match pause_before with Some v -> ("pause-before", "pause_before", v) :: acc | None -> acc in
  let acc = match pitch with Some v -> ("pitch", "pitch", v) :: acc | None -> acc in
  let acc = match pitch_range with Some v -> ("pitch-range", "pitch_range", v) :: acc | None -> acc in
  let acc = match play_during with Some v -> ("play-during", "play_during", v) :: acc | None -> acc in
  let acc = match position with Some v -> ("position", "position", v) :: acc | None -> acc in
  let acc = match quotes with Some v -> ("quotes", "quotes", v) :: acc | None -> acc in
  let acc = match richness with Some v -> ("richness", "richness", v) :: acc | None -> acc in
  let acc = match right with Some v -> ("right", "right", v) :: acc | None -> acc in
  let acc = match size with Some v -> ("size", "size", v) :: acc | None -> acc in
  let acc = match speak with Some v -> ("speak", "speak", v) :: acc | None -> acc in
  let acc = match speak_header with Some v -> ("speak-header", "speak_header", v) :: acc | None -> acc in
  let acc = match speak_numeral with Some v -> ("speak-numeral", "speak_numeral", v) :: acc | None -> acc in
  let acc = match speak_punctuation with Some v -> ("speak-punctuation", "speak_punctuation", v) :: acc | None -> acc in
  let acc = match speech_rate with Some v -> ("speech-rate", "speech_rate", v) :: acc | None -> acc in
  let acc = match stress with Some v -> ("stress", "stress", v) :: acc | None -> acc in
  let acc = match table_layout with Some v -> ("table-layout", "table_layout", v) :: acc | None -> acc in
  let acc = match text_align with Some v -> ("text-align", "text_align", v) :: acc | None -> acc in
  let acc = match text_decoration with Some v -> ("text-decoration", "text_decoration", v) :: acc | None -> acc in
  let acc = match text_indent with Some v -> ("text-indent", "text_indent", v) :: acc | None -> acc in
  let acc = match text_shadow with Some v -> ("text-shadow", "text_shadow", v) :: acc | None -> acc in
  let acc = match text_transform with Some v -> ("text-transform", "text_transform", v) :: acc | None -> acc in
  let acc = match top with Some v -> ("top", "top", v) :: acc | None -> acc in
  let acc = match unicode_bidi with Some v -> ("unicode-bidi", "unicode_bidi", v) :: acc | None -> acc in
  let acc = match vertical_align with Some v -> ("vertical-align", "vertical_align", v) :: acc | None -> acc in
  let acc = match visibility with Some v -> ("visibility", "visibility", v) :: acc | None -> acc in
  let acc = match voice_family with Some v -> ("voice-family", "voice_family", v) :: acc | None -> acc in
  let acc = match volume with Some v -> ("volume", "volume", v) :: acc | None -> acc in
  let acc = match white_space with Some v -> ("white-space", "white_space", v) :: acc | None -> acc in
  let acc = match widows with Some v -> ("widows", "widows", v) :: acc | None -> acc in
  let acc = match width with Some v -> ("width", "width", v) :: acc | None -> acc in
  let acc = match word_spacing with Some v -> ("word-spacing", "word_spacing", v) :: acc | None -> acc in
  let acc = match z_index with Some v -> ("z-index", "z_index", v) :: acc | None -> acc in
  let acc = match opacity with Some v -> ("opacity", "opacity", v) :: acc | None -> acc in
  let acc = match background_origin with Some v -> ("background-origin", "background_origin", v) :: acc | None -> acc in
  let acc = match background_size with Some v -> ("background-size", "background_size", v) :: acc | None -> acc in
  let acc = match background_clip with Some v -> ("background-clip", "background_clip", v) :: acc | None -> acc in
  let acc = match border_radius with Some v -> ("border-radius", "border_radius", v) :: acc | None -> acc in
  let acc = match border_top_left_radius with Some v -> ("border-top-left-radius", "border_top_left_radius", v) :: acc | None -> acc in
  let acc = match border_top_right_radius with Some v -> ("border-top-right-radius", "border_top_right_radius", v) :: acc | None -> acc in
  let acc = match border_bottom_left_radius with Some v -> ("border-bottom-left-radius", "border_bottom_left_radius", v) :: acc | None -> acc in
  let acc = match border_bottom_right_radius with Some v -> ("border-bottom-right-radius", "border_bottom_right_radius", v) :: acc | None -> acc in
  let acc = match border_image with Some v -> ("border-image", "border_image", v) :: acc | None -> acc in
  let acc = match border_image_source with Some v -> ("border-image-source", "border_image_source", v) :: acc | None -> acc in
  let acc = match border_image_slice with Some v -> ("border-image-slice", "border_image_slice", v) :: acc | None -> acc in
  let acc = match border_image_width with Some v -> ("border-image-width", "border_image_width", v) :: acc | None -> acc in
  let acc = match border_image_outset with Some v -> ("border-image-outset", "border_image_outset", v) :: acc | None -> acc in
  let acc = match border_image_repeat with Some v -> ("border-image-repeat", "border_image_repeat", v) :: acc | None -> acc in
  let acc = match box_shadow with Some v -> ("box-shadow", "box_shadow", v) :: acc | None -> acc in
  let acc = match columns with Some v -> ("columns", "columns", v) :: acc | None -> acc in
  let acc = match column_count with Some v -> ("column-count", "column_count", v) :: acc | None -> acc in
  let acc = match column_fill with Some v -> ("column-fill", "column_fill", v) :: acc | None -> acc in
  let acc = match column_gap with Some v -> ("column-gap", "column_gap", v) :: acc | None -> acc in
  let acc = match column_rule with Some v -> ("column-rule", "column_rule", v) :: acc | None -> acc in
  let acc = match column_rule_color with Some v -> ("column-rule-color", "column_rule_color", v) :: acc | None -> acc in
  let acc = match column_rule_style with Some v -> ("column-rule-style", "column_rule_style", v) :: acc | None -> acc in
  let acc = match column_rule_width with Some v -> ("column-rule-width", "column_rule_width", v) :: acc | None -> acc in
  let acc = match column_span with Some v -> ("column-span", "column_span", v) :: acc | None -> acc in
  let acc = match column_width with Some v -> ("column-width", "column_width", v) :: acc | None -> acc in
  let acc = match break_after with Some v -> ("break-after", "break_after", v) :: acc | None -> acc in
  let acc = match break_before with Some v -> ("break-before", "break_before", v) :: acc | None -> acc in
  let acc = match break_inside with Some v -> ("break-inside", "break_inside", v) :: acc | None -> acc in
  let acc = match rest with Some v -> ("rest", "rest", v) :: acc | None -> acc in
  let acc = match rest_after with Some v -> ("rest-after", "rest_after", v) :: acc | None -> acc in
  let acc = match rest_before with Some v -> ("rest-before", "rest_before", v) :: acc | None -> acc in
  let acc = match speak_as with Some v -> ("speak-as", "speak_as", v) :: acc | None -> acc in
  let acc = match voice_balance with Some v -> ("voice-balance", "voice_balance", v) :: acc | None -> acc in
  let acc = match voice_duration with Some v -> ("voice-duration", "voice_duration", v) :: acc | None -> acc in
  let acc = match voice_pitch with Some v -> ("voice-pitch", "voice_pitch", v) :: acc | None -> acc in
  let acc = match voice_range with Some v -> ("voice-range", "voice_range", v) :: acc | None -> acc in
  let acc = match voice_rate with Some v -> ("voice-rate", "voice_rate", v) :: acc | None -> acc in
  let acc = match voice_stress with Some v -> ("voice-stress", "voice_stress", v) :: acc | None -> acc in
  let acc = match voice_volume with Some v -> ("voice-volume", "voice_volume", v) :: acc | None -> acc in
  let acc = match object_fit with Some v -> ("object-fit", "object_fit", v) :: acc | None -> acc in
  let acc = match object_position with Some v -> ("object-position", "object_position", v) :: acc | None -> acc in
  let acc = match image_resolution with Some v -> ("image-resolution", "image_resolution", v) :: acc | None -> acc in
  let acc = match image_orientation with Some v -> ("image-orientation", "image_orientation", v) :: acc | None -> acc in
  let acc = match align_content with Some v -> ("align-content", "align_content", v) :: acc | None -> acc in
  let acc = match align_items with Some v -> ("align-items", "align_items", v) :: acc | None -> acc in
  let acc = match align_self with Some v -> ("align-self", "align_self", v) :: acc | None -> acc in
  let acc = match flex with Some v -> ("flex", "flex", v) :: acc | None -> acc in
  let acc = match flex_basis with Some v -> ("flex-basis", "flex_basis", v) :: acc | None -> acc in
  let acc = match flex_direction with Some v -> ("flex-direction", "flex_direction", v) :: acc | None -> acc in
  let acc = match flex_flow with Some v -> ("flex-flow", "flex_flow", v) :: acc | None -> acc in
  let acc = match flex_grow with Some v -> ("flex-grow", "flex_grow", v) :: acc | None -> acc in
  let acc = match flex_shrink with Some v -> ("flex-shrink", "flex_shrink", v) :: acc | None -> acc in
  let acc = match flex_wrap with Some v -> ("flex-wrap", "flex_wrap", v) :: acc | None -> acc in
  let acc = match justify_content with Some v -> ("justify-content", "justify_content", v) :: acc | None -> acc in
  let acc = match order with Some v -> ("order", "order", v) :: acc | None -> acc in
  let acc = match text_decoration_color with Some v -> ("text-decoration-color", "text_decoration_color", v) :: acc | None -> acc in
  let acc = match text_decoration_line with Some v -> ("text-decoration-line", "text_decoration_line", v) :: acc | None -> acc in
  let acc = match text_decoration_skip with Some v -> ("text-decoration-skip", "text_decoration_skip", v) :: acc | None -> acc in
  let acc = match text_decoration_style with Some v -> ("text-decoration-style", "text_decoration_style", v) :: acc | None -> acc in
  let acc = match text_emphasis with Some v -> ("text-emphasis", "text_emphasis", v) :: acc | None -> acc in
  let acc = match text_emphasis_color with Some v -> ("text-emphasis-color", "text_emphasis_color", v) :: acc | None -> acc in
  let acc = match text_emphasis_position with Some v -> ("text-emphasis-position", "text_emphasis_position", v) :: acc | None -> acc in
  let acc = match text_emphasis_style with Some v -> ("text-emphasis-style", "text_emphasis_style", v) :: acc | None -> acc in
  let acc = match text_underline_position with Some v -> ("text-underline-position", "text_underline_position", v) :: acc | None -> acc in
  let acc = match font_feature_settings with Some v -> ("font-feature-settings", "font_feature_settings", v) :: acc | None -> acc in
  let acc = match font_kerning with Some v -> ("font-kerning", "font_kerning", v) :: acc | None -> acc in
  let acc = match font_language_override with Some v -> ("font-language-override", "font_language_override", v) :: acc | None -> acc in
  let acc = match font_synthesis with Some v -> ("font-synthesis", "font_synthesis", v) :: acc | None -> acc in
  let acc = match forntVariantAlternates with Some v -> ("fornt-variant-alternates", "fornt_variant_alternates", v) :: acc | None -> acc in
  let acc = match font_variant_caps with Some v -> ("font-variant-caps", "font_variant_caps", v) :: acc | None -> acc in
  let acc = match font_variant_east_asian with Some v -> ("font-variant-east-asian", "font_variant_east_asian", v) :: acc | None -> acc in
  let acc = match font_variant_ligatures with Some v -> ("font-variant-ligatures", "font_variant_ligatures", v) :: acc | None -> acc in
  let acc = match font_variant_numeric with Some v -> ("font-variant-numeric", "font_variant_numeric", v) :: acc | None -> acc in
  let acc = match font_variant_position with Some v -> ("font-variant-position", "font_variant_position", v) :: acc | None -> acc in
  let acc = match all with Some v -> ("all", "all", v) :: acc | None -> acc in
  let acc = match glyph_orientation_vertical with Some v -> ("glyph-orientation-vertical", "glyph_orientation_vertical", v) :: acc | None -> acc in
  let acc = match text_combine_upright with Some v -> ("text-combine-upright", "text_combine_upright", v) :: acc | None -> acc in
  let acc = match text_orientation with Some v -> ("text-orientation", "text_orientation", v) :: acc | None -> acc in
  let acc = match writing_mode with Some v -> ("writing-mode", "writing_mode", v) :: acc | None -> acc in
  let acc = match shape_image_threshold with Some v -> ("shape-image-threshold", "shape_image_threshold", v) :: acc | None -> acc in
  let acc = match shape_margin with Some v -> ("shape-margin", "shape_margin", v) :: acc | None -> acc in
  let acc = match shape_outside with Some v -> ("shape-outside", "shape_outside", v) :: acc | None -> acc in
  let acc = match clip_path with Some v -> ("clip-path", "clip_path", v) :: acc | None -> acc in
  let acc = match clip_rule with Some v -> ("clip-rule", "clip_rule", v) :: acc | None -> acc in
  let acc = match mask with Some v -> ("mask", "mask", v) :: acc | None -> acc in
  let acc = match mask_border with Some v -> ("mask-border", "mask_border", v) :: acc | None -> acc in
  let acc = match mask_border_mode with Some v -> ("mask-border-mode", "mask_border_mode", v) :: acc | None -> acc in
  let acc = match mask_border_outset with Some v -> ("mask-border-outset", "mask_border_outset", v) :: acc | None -> acc in
  let acc = match mask_border_repeat with Some v -> ("mask-border-repeat", "mask_border_repeat", v) :: acc | None -> acc in
  let acc = match mask_border_slice with Some v -> ("mask-border-slice", "mask_border_slice", v) :: acc | None -> acc in
  let acc = match mask_border_source with Some v -> ("mask-border-source", "mask_border_source", v) :: acc | None -> acc in
  let acc = match mask_border_width with Some v -> ("mask-border-width", "mask_border_width", v) :: acc | None -> acc in
  let acc = match mask_clip with Some v -> ("mask-clip", "mask_clip", v) :: acc | None -> acc in
  let acc = match mask_composite with Some v -> ("mask-composite", "mask_composite", v) :: acc | None -> acc in
  let acc = match mask_image with Some v -> ("mask-image", "mask_image", v) :: acc | None -> acc in
  let acc = match mask_mode with Some v -> ("mask-mode", "mask_mode", v) :: acc | None -> acc in
  let acc = match mask_origin with Some v -> ("mask-origin", "mask_origin", v) :: acc | None -> acc in
  let acc = match mask_position with Some v -> ("mask-position", "mask_position", v) :: acc | None -> acc in
  let acc = match mask_repeat with Some v -> ("mask-repeat", "mask_repeat", v) :: acc | None -> acc in
  let acc = match mask_size with Some v -> ("mask-size", "mask_size", v) :: acc | None -> acc in
  let acc = match mask_type with Some v -> ("mask-type", "mask_type", v) :: acc | None -> acc in
  let acc = match background_blend_mode with Some v -> ("background-blend-mode", "background_blend_mode", v) :: acc | None -> acc in
  let acc = match isolation with Some v -> ("isolation", "isolation", v) :: acc | None -> acc in
  let acc = match mix_blend_mode with Some v -> ("mix-blend-mode", "mix_blend_mode", v) :: acc | None -> acc in
  let acc = match box_decoration_break with Some v -> ("box-decoration-break", "box_decoration_break", v) :: acc | None -> acc in
  let acc = match box_sizing with Some v -> ("box-sizing", "box_sizing", v) :: acc | None -> acc in
  let acc = match caret_color with Some v -> ("caret-color", "caret_color", v) :: acc | None -> acc in
  let acc = match nav_down with Some v -> ("nav-down", "nav_down", v) :: acc | None -> acc in
  let acc = match nav_left with Some v -> ("nav-left", "nav_left", v) :: acc | None -> acc in
  let acc = match nav_right with Some v -> ("nav-right", "nav_right", v) :: acc | None -> acc in
  let acc = match nav_up with Some v -> ("nav-up", "nav_up", v) :: acc | None -> acc in
  let acc = match outline_offset with Some v -> ("outline-offset", "outline_offset", v) :: acc | None -> acc in
  let acc = match resize with Some v -> ("resize", "resize", v) :: acc | None -> acc in
  let acc = match text_overflow with Some v -> ("text-overflow", "text_overflow", v) :: acc | None -> acc in
  let acc = match grid with Some v -> ("grid", "grid", v) :: acc | None -> acc in
  let acc = match grid_area with Some v -> ("grid-area", "grid_area", v) :: acc | None -> acc in
  let acc = match grid_auto_columns with Some v -> ("grid-auto-columns", "grid_auto_columns", v) :: acc | None -> acc in
  let acc = match grid_auto_flow with Some v -> ("grid-auto-flow", "grid_auto_flow", v) :: acc | None -> acc in
  let acc = match grid_auto_rows with Some v -> ("grid-auto-rows", "grid_auto_rows", v) :: acc | None -> acc in
  let acc = match grid_column with Some v -> ("grid-column", "grid_column", v) :: acc | None -> acc in
  let acc = match grid_column_end with Some v -> ("grid-column-end", "grid_column_end", v) :: acc | None -> acc in
  let acc = match grid_column_gap with Some v -> ("grid-column-gap", "grid_column_gap", v) :: acc | None -> acc in
  let acc = match grid_column_start with Some v -> ("grid-column-start", "grid_column_start", v) :: acc | None -> acc in
  let acc = match grid_gap with Some v -> ("grid-gap", "grid_gap", v) :: acc | None -> acc in
  let acc = match grid_row with Some v -> ("grid-row", "grid_row", v) :: acc | None -> acc in
  let acc = match grid_row_end with Some v -> ("grid-row-end", "grid_row_end", v) :: acc | None -> acc in
  let acc = match grid_row_gap with Some v -> ("grid-row-gap", "grid_row_gap", v) :: acc | None -> acc in
  let acc = match grid_row_start with Some v -> ("grid-row-start", "grid_row_start", v) :: acc | None -> acc in
  let acc = match grid_template with Some v -> ("grid-template", "grid_template", v) :: acc | None -> acc in
  let acc = match grid_template_areas with Some v -> ("grid-template-areas", "grid_template_areas", v) :: acc | None -> acc in
  let acc = match grid_template_columns with Some v -> ("grid-template-columns", "grid_template_columns", v) :: acc | None -> acc in
  let acc = match grid_template_rows with Some v -> ("grid-template-rows", "grid_template_rows", v) :: acc | None -> acc in
  let acc = match will_change with Some v -> ("will-change", "will_change", v) :: acc | None -> acc in
  let acc = match hanging_punctuation with Some v -> ("hanging-punctuation", "hanging_punctuation", v) :: acc | None -> acc in
  let acc = match hyphens with Some v -> ("hyphens", "hyphens", v) :: acc | None -> acc in
  let acc = match line_break with Some v -> ("line-break", "line_break", v) :: acc | None -> acc in
  let acc = match overflow_wrap with Some v -> ("overflow-wrap", "overflow_wrap", v) :: acc | None -> acc in
  let acc = match tab_size with Some v -> ("tab-size", "tab_size", v) :: acc | None -> acc in
  let acc = match text_align_last with Some v -> ("text-align-last", "text_align_last", v) :: acc | None -> acc in
  let acc = match text_justify with Some v -> ("text-justify", "text_justify", v) :: acc | None -> acc in
  let acc = match word_break with Some v -> ("word-break", "word_break", v) :: acc | None -> acc in
  let acc = match word_wrap with Some v -> ("word-wrap", "word_wrap", v) :: acc | None -> acc in
  let acc = match animation with Some v -> ("animation", "animation", v) :: acc | None -> acc in
  let acc = match animation_delay with Some v -> ("animation-delay", "animation_delay", v) :: acc | None -> acc in
  let acc = match animation_direction with Some v -> ("animation-direction", "animation_direction", v) :: acc | None -> acc in
  let acc = match animation_duration with Some v -> ("animation-duration", "animation_duration", v) :: acc | None -> acc in
  let acc = match animation_fill_mode with Some v -> ("animation-fill-mode", "animation_fill_mode", v) :: acc | None -> acc in
  let acc = match animation_iteration_count with Some v -> ("animation-iteration-count", "animation_iteration_count", v) :: acc | None -> acc in
  let acc = match animation_name with Some v -> ("animation-name", "animation_name", v) :: acc | None -> acc in
  let acc = match animation_play_state with Some v -> ("animation-play-state", "animation_play_state", v) :: acc | None -> acc in
  let acc = match animation_timing_function with Some v -> ("animation-timing-function", "animation_timing_function", v) :: acc | None -> acc in
  let acc = match transition with Some v -> ("transition", "transition", v) :: acc | None -> acc in
  let acc = match transition_delay with Some v -> ("transition-delay", "transition_delay", v) :: acc | None -> acc in
  let acc = match transition_duration with Some v -> ("transition-duration", "transition_duration", v) :: acc | None -> acc in
  let acc = match transition_property with Some v -> ("transition-property", "transition_property", v) :: acc | None -> acc in
  let acc = match transition_timing_function with Some v -> ("transition-timing-function", "transition_timing_function", v) :: acc | None -> acc in
  let acc = match backface_visibility with Some v -> ("backface-visibility", "backface_visibility", v) :: acc | None -> acc in
  let acc = match perspective with Some v -> ("perspective", "perspective", v) :: acc | None -> acc in
  let acc = match perspective_origin with Some v -> ("perspective-origin", "perspective_origin", v) :: acc | None -> acc in
  let acc = match transform with Some v -> ("transform", "transform", v) :: acc | None -> acc in
  let acc = match transform_origin with Some v -> ("transform-origin", "transform_origin", v) :: acc | None -> acc in
  let acc = match transform_style with Some v -> ("transform-style", "transform_style", v) :: acc | None -> acc in
  let acc = match justify_items with Some v -> ("justify-items", "justify_items", v) :: acc | None -> acc in
  let acc = match justify_self with Some v -> ("justify-self", "justify_self", v) :: acc | None -> acc in
  let acc = match place_content with Some v -> ("place-content", "place_content", v) :: acc | None -> acc in
  let acc = match place_items with Some v -> ("place-items", "place_items", v) :: acc | None -> acc in
  let acc = match place_self with Some v -> ("place-self", "place_self", v) :: acc | None -> acc in
  let acc = match appearance with Some v -> ("appearance", "appearance", v) :: acc | None -> acc in
  let acc = match caret with Some v -> ("caret", "caret", v) :: acc | None -> acc in
  let acc = match caret_animation with Some v -> ("caret-animation", "caret_animation", v) :: acc | None -> acc in
  let acc = match caret_shape with Some v -> ("caret-shape", "caret_shape", v) :: acc | None -> acc in
  let acc = match user_select with Some v -> ("user-select", "user_select", v) :: acc | None -> acc in
  let acc = match max_lines with Some v -> ("max-lines", "max_lines", v) :: acc | None -> acc in
  let acc = match marquee_direction with Some v -> ("marquee-direction", "marquee_direction", v) :: acc | None -> acc in
  let acc = match marquee_loop with Some v -> ("marquee-loop", "marquee_loop", v) :: acc | None -> acc in
  let acc = match marquee_speed with Some v -> ("marquee-speed", "marquee_speed", v) :: acc | None -> acc in
  let acc = match marquee_style with Some v -> ("marquee-style", "marquee_style", v) :: acc | None -> acc in
  let acc = match overflow_style with Some v -> ("overflow-style", "overflow_style", v) :: acc | None -> acc in
  let acc = match rotation with Some v -> ("rotation", "rotation", v) :: acc | None -> acc in
  let acc = match rotation_point with Some v -> ("rotation-point", "rotation_point", v) :: acc | None -> acc in
  let acc = match alignment_baseline with Some v -> ("alignment-baseline", "alignment_baseline", v) :: acc | None -> acc in
  let acc = match baseline_shift with Some v -> ("baseline-shift", "baseline_shift", v) :: acc | None -> acc in
  let acc = match clip with Some v -> ("clip", "clip", v) :: acc | None -> acc in
  let acc = match clip_path with Some v -> ("clip-path", "clip_path", v) :: acc | None -> acc in
  let acc = match clip_rule with Some v -> ("clip-rule", "clip_rule", v) :: acc | None -> acc in
  let acc = match color_interpolation with Some v -> ("color-interpolation", "color_interpolation", v) :: acc | None -> acc in
  let acc = match color_interpolation_filters with Some v -> ("color-interpolation-filters", "color_interpolation_filters", v) :: acc | None -> acc in
  let acc = match color_profile with Some v -> ("color-profile", "color_profile", v) :: acc | None -> acc in
  let acc = match color_rendering with Some v -> ("color-rendering", "color_rendering", v) :: acc | None -> acc in
  let acc = match cursor with Some v -> ("cursor", "cursor", v) :: acc | None -> acc in
  let acc = match dominant_baseline with Some v -> ("dominant-baseline", "dominant_baseline", v) :: acc | None -> acc in
  let acc = match fill with Some v -> ("fill", "fill", v) :: acc | None -> acc in
  let acc = match fill_opacity with Some v -> ("fill-opacity", "fill_opacity", v) :: acc | None -> acc in
  let acc = match fill_rule with Some v -> ("fill-rule", "fill_rule", v) :: acc | None -> acc in
  let acc = match filter with Some v -> ("filter", "filter", v) :: acc | None -> acc in
  let acc = match flood_color with Some v -> ("flood-color", "flood_color", v) :: acc | None -> acc in
  let acc = match flood_opacity with Some v -> ("flood-opacity", "flood_opacity", v) :: acc | None -> acc in
  let acc = match glyph_orientation_horizontal with Some v -> ("glyph-orientation-horizontal", "glyph_orientation_horizontal", v) :: acc | None -> acc in
  let acc = match glyph_orientation_vertical with Some v -> ("glyph-orientation-vertical", "glyph_orientation_vertical", v) :: acc | None -> acc in
  let acc = match image_rendering with Some v -> ("image-rendering", "image_rendering", v) :: acc | None -> acc in
  let acc = match kerning with Some v -> ("kerning", "kerning", v) :: acc | None -> acc in
  let acc = match lighting_color with Some v -> ("lighting-color", "lighting_color", v) :: acc | None -> acc in
  let acc = match marker_end with Some v -> ("marker-end", "marker_end", v) :: acc | None -> acc in
  let acc = match marker_mid with Some v -> ("marker-mid", "marker_mid", v) :: acc | None -> acc in
  let acc = match marker_start with Some v -> ("marker-start", "marker_start", v) :: acc | None -> acc in
  let acc = match pointer_events with Some v -> ("pointer-events", "pointer_events", v) :: acc | None -> acc in
  let acc = match shape_rendering with Some v -> ("shape-rendering", "shape_rendering", v) :: acc | None -> acc in
  let acc = match stop_color with Some v -> ("stop-color", "stop_color", v) :: acc | None -> acc in
  let acc = match stop_opacity with Some v -> ("stop-opacity", "stop_opacity", v) :: acc | None -> acc in
  let acc = match stroke with Some v -> ("stroke", "stroke", v) :: acc | None -> acc in
  let acc = match stroke_dasharray with Some v -> ("stroke-dasharray", "stroke_dasharray", v) :: acc | None -> acc in
  let acc = match stroke_dashoffset with Some v -> ("stroke-dashoffset", "stroke_dashoffset", v) :: acc | None -> acc in
  let acc = match stroke_linecap with Some v -> ("stroke-linecap", "stroke_linecap", v) :: acc | None -> acc in
  let acc = match stroke_linejoin with Some v -> ("stroke-linejoin", "stroke_linejoin", v) :: acc | None -> acc in
  let acc = match stroke_miterlimit with Some v -> ("stroke-miterlimit", "stroke_miterlimit", v) :: acc | None -> acc in
  let acc = match stroke_opacity with Some v -> ("stroke-opacity", "stroke_opacity", v) :: acc | None -> acc in
  let acc = match stroke_width with Some v -> ("stroke-width", "stroke_width", v) :: acc | None -> acc in
  let acc = match text_anchor with Some v -> ("text-anchor", "text_anchor", v) :: acc | None -> acc in
  let acc = match text_rendering with Some v -> ("text-rendering", "text_rendering", v) :: acc | None -> acc in
  let acc = match ruby_align with Some v -> ("ruby-align", "ruby_align", v) :: acc | None -> acc in
  let acc = match ruby_merge with Some v -> ("ruby-merge", "ruby_merge", v) :: acc | None -> acc in
  let acc = match ruby_position with Some v -> ("ruby-position", "ruby_position", v) :: acc | None -> acc in
  List.rev acc
[@@@ocamlformat "enable"]

let write_to_buffer buf (styles : t) : unit =
  let rec loop first = function
    | [] -> ()
    | (k, _, v) :: rest ->
        (* Skip empty values structurally, not with [==]: it must match the
           PPX static fold. *)
        if String.length v = 0 then loop first rest
        else (
          if not first then Buffer.add_char buf ';';
          Buffer.add_string buf k;
          Buffer.add_char buf ':';
          Buffer.add_string buf (String.trim v);
          loop false rest)
  in
  loop true styles

let to_string (styles : t) : string =
  let buf = Buffer.create 64 in
  write_to_buffer buf styles;
  Buffer.contents buf

(* TODO: Remove conversion to sequences, can do List.combine *)
let combine (styles1 : t) (styles2 : t) : t =
  let seq1 = styles1 |> List.to_seq in
  let seq2 = styles2 |> List.to_seq in
  Seq.append seq1 seq2 |> List.of_seq

let camelcase_to_kebabcase str =
  let len = String.length str in
  let is_uppercase c = c >= 'A' && c <= 'Z' in
  let is_custom_property str = len >= 2 && str.[0] = '-' && str.[1] = '-' in
  if is_custom_property str then str
  else
    let buf = Buffer.create (len + 4) in
    for i = 0 to len - 1 do
      let c = str.[i] in
      if i > 0 && is_uppercase c then begin
        Buffer.add_char buf '-';
        Buffer.add_char buf (Char.lowercase_ascii c)
      end
      else Buffer.add_char buf c
    done;
    Buffer.contents buf

let unsafe_add_prop styles key value : t =
  (* Adds the (key, value) into last position, mirroring reason-react's
     Object.assign semantics where a new key lands at the end. *)
  styles @ [ (camelcase_to_kebabcase key, key, value) ]
