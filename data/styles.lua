local styles = data.raw['gui-style'].default

styles.ctron_title_dragbar = {
    type = "empty_widget_style",
    parent = "draggable_space_header",

    height = 24,

    left_margin = 4,
    right_margin = 4,

    horizontally_stretchable = "on"
}

styles.ctron_frame_button = {
    type = "button_style",
    parent = "frame_button",

    height = 24,
    minimal_width = 0,

    left_padding = 8,
    right_padding = 8,

    font = "heading-2",
    default_font_color = {0.9, 0.9, 0.9},
    hovered_font_color = {0, 0, 0},
    selected_font_color = {0, 0, 0},
    disabled_font_color = {0.701961, 0.701961, 0.701961}
}

styles.ctron_frame_dropdown = {
    type = "dropdown_style",
    parent = "dropdown",
    
    height = 24,
    minimal_width = 80,

    top_padding = -4,
    left_padding = 8,
    right_padding = 2,
    
    button_style = {
        type = "button_style",
        parent = "ctron_frame_button",
    },

    list_box_style = {
        type = "list_box_style",

        item_style = {
            type = "button_style",
            parent = "ctron_frame_button"
        }
    }
}

styles.ctron_entity_scroll = {
    type = "scroll_pane_style",
    parent = "scroll_pane_with_dark_background_under_subheader",

    minimal_height = 304,
    --natural_height = 710,
    maximal_height = 912,

    padding = 0,
    extra_padding_when_activated = 0,

    vertically_stretchable = "stretch_and_expand",
    vertically_squashable = "on",

    background_graphical_set = {
        corner_size = 8,
        overall_tiling_horizontal_padding = 8,
        overall_tiling_horizontal_size = 568,
        overall_tiling_horizontal_spacing = 16,
        overall_tiling_vertical_padding = 8,
        overall_tiling_vertical_size = 288,
        overall_tiling_vertical_spacing = 16,
        position = {
            282,
            17
        }
    }
}

styles.ctron_idle_entity_scroll = {
    type = "scroll_pane_style",
    parent = "ctron_entity_scroll",

    background_graphical_set = {
        corner_size = 8,
        overall_tiling_horizontal_padding = 8,
        overall_tiling_horizontal_size = 276,
        overall_tiling_horizontal_spacing = 16,
        overall_tiling_vertical_padding = 8,
        overall_tiling_vertical_size = 288,
        overall_tiling_vertical_spacing = 16,
        position = {
            282,
            17
        }
    }
}

styles.ctron_entity_table = {
    type = "table_style",
    parent = "table",

    width = 1168,

    horizontal_spacing = 0,
    vertical_spacing = 0,

    horizontally_stretchable = "on",
    vertically_stretchable = "on"
}
