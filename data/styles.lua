local styles = data.raw['gui-style'].default

styles.ctron_main_frame = {
    type = "frame_style",
    parent = "frame",

    height = 822,
    width = 1204
}

styles.ctron_title_bar_flow = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",

    height = 28,

    horizontal_spacing = 8,
}

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

styles.ctron_tab_pane_frame = {
    type = "frame_style",
    parent = "inside_deep_frame_for_tabs",

    height = 770,
    width = 1180
}

styles.ctron_tabbed_pane = {
    type = "tabbed_pane_style",
    parent = "tabbed_pane",

    height = 758,
    width = 1180,

    vertically_stretchable = "off",
    horizontally_stretchable = "off",

    tab_content_frame = {
        type = "frame_style",
        parent = "tabbed_pane_frame",

        top_padding = 8,
        bottom_padding = 0,
        left_padding = 0,
        right_padding = 0
    }
}

styles.ctron_tab_flow = {
    type = "horizontal_flow_style",
    parent = "inset_frame_container_horizontal_flow_in_tabbed_pane",

    height = 714,
    width = 1180,

    padding = 0
}

styles.ctron_entity_list_frame = {
    type = "frame_style",
    parent = "deep_frame_in_shallow_frame",

    height = 710,
    width = 1180
}

styles.ctron_entity_scroll = {
    type = "scroll_pane_style",
    parent = "scroll_pane_with_dark_background_under_subheader",

    height = 710,
    width = 1180,

    padding = 0,
    extra_padding_when_activated = 0,

    vertically_stretchable = "stretch_and_expand",

    vertical_flow_style = {
        type = "vertical_flow_style",
        vertical_spacing = 0,

        minimal_height = 912
    },

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

styles.ctron_entity_item_map_button = {
    type = "button_style",
    parent = "locomotive_minimap_button",

    height = 236,
    width = 268
}

styles.ctron_entity_item_map = {
    type = "minimap_style",
    parent = "minimap",

    height = 236,
    width = 268
}

styles.ctron_entity_item_inventory_frame = {
    type = "frame_style",
    parent = "slot_button_deep_frame",

    height = 280,
    width = 280
}

styles.ctron_entity_item_inventory_table = {
    type = "table_style",
    parent = "table",

    horizontal_spacing = 0,
    vertical_spacing = 0
}
