local styles = data.raw['gui-style'].default

--===========================================================================--
-- Shared GUI - Styles
--===========================================================================--

styles.ctron_title_bar_drag_bar_style = {
    type = "empty_widget_style",
    parent = "draggable_space_header",
    height = 24,
    left_margin = 4,
    right_margin = 4,
    horizontally_stretchable = "on"
}

styles.ctron_surface_dropdown_style = {
    type = "dropdown_style",
    parent = "dropdown",
    height = 24,
    minimal_width = 80,
    maximal_width = 160,
    top_padding = -4,
    left_padding = 8,
    right_padding = 2,
    button_style = {
        type = "button_style",
        parent = "ctron_frame_button_style",
    },
    list_box_style = {
        type = "list_box_style",
        item_style = {
            type = "button_style",
            parent = "ctron_frame_button_style"
        }
    }
}

styles.ctron_frame_button_style = {
    type = "button_style",
    parent = "frame_button",
    height = 24,
    minimal_width = 76,
    left_padding = 8,
    right_padding = 8,
    font = "heading-2",
    default_font_color = {0.9, 0.9, 0.9},
    hovered_font_color = {0, 0, 0},
    selected_font_color = {0, 0, 0},
    disabled_font_color = {0.701961, 0.701961, 0.701961}
}

styles.ctron_title_bar_flow_style = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    height = 28,
    horizontal_spacing = 8,
}

--===========================================================================--
-- Main GUI - Styles
--===========================================================================--

styles.ctron_stat_card_style = {
    type = "frame_style",
    parent = "inside_deep_frame",
    padding = 0,
    horizontal_align = "center",
}

styles.ctron_stat_card_label_style = {
    type = "label_style",
    parent = "frame_title",
    width = 250,
    horizontal_align = "center",
    vertical_align = "center"
}

styles.ctron_main_content_style = {
    type = "frame_style",
    parent = "inside_deep_frame",
    padding = 0,
    height = 710,
    width = 1180
}

-- styles.ctron_main_scroll_section_style = {
--     type = "scroll_pane_style",
--     -- parent = "inner_frame_scroll_pane", -- TODO
--     height = 710,
--     width = 1180,
--     padding = 0,
--     extra_padding_when_activated = 0,
--     vertically_stretchable = "stretch_and_expand",
--     vertical_flow_style = {
--         type = "vertical_flow_style",
--         vertical_spacing = 0,
--         minimal_height = 932
--     },
-- }

styles.ctron_main_scroll_section_style = {
    type = "scroll_pane_style",
    parent = "deep_scroll_pane",
    height = 710,
    width = 1180,
    padding = 0,
    extra_padding_when_activated = 0,
    vertically_stretchable = "stretch_and_expand",
    vertical_flow_style = {
        type = "vertical_flow_style",
        vertical_spacing = 0,
        -- minimal_height = 932
    },
}

styles.ctron_job_status_section_style = {
    type = "frame_style",
    parent = "inside_deep_frame",
    padding = 0,
    horizontal_align = "center",
}

styles.ctron_job_card_style = {
    type = "frame_style",
    parent = "frame",
    top_padding = 2,
    bottom_padding = 2,
}

styles.ctron_job_status_section_flow_style = {
    type = "horizontal_flow_style",
    parent = "inset_frame_container_horizontal_flow_in_tabbed_pane",
    left_margin = 4,
    right_margin = 4,
}

styles.ctron_job_section_title_bar_style = {
    type = "empty_widget_style",
    parent = "draggable_space_header",
    horizontally_stretchable = "on"
}

styles.ctron_job_section_label_style = {
    type = "label_style",
    parent = "bold_label",
    width = 144,
    left_padding = 40,
    right_padding = 4,
    horizontal_align = "center",
    vertical_align = "center"
}

styles.ctron_collapse_expand_button_style = {
    type = "button_style",
    parent = "slot_button",
    height = 24,
    width = 24,
}

styles.ctron_job_label_frame_style = {
    type = "frame_style",
    parent = "inside_deep_frame",
    padding = 0,
    horizontal_align = "center",
}

styles.ctron_job_type_label_style = {
    type = "label_style",
    parent = "frame_title",
    width = 180,
    horizontal_align = "center",
    vertical_align = "center"
}

styles.ctron_chunk_card_style = {
    type = "frame_style",
    parent = "frame",
    top_padding = 2,
    bottom_padding = 2,
}

styles.ctron_chunk_label_frame_style = {
    type = "frame_style",
    parent = "inside_deep_frame",
    padding = 0,
    horizontal_align = "center",
}

styles.ctron_chunk_label_style = {
    type = "label_style",
    parent = "frame_title",
    width = 180,
    horizontal_align = "center",
    vertical_align = "center"
}

--===========================================================================--
-- Settings GUI - Styles
--===========================================================================--

styles.ctron_settings_inner_frame_style = {
    type = "frame_style",
    parent = "entity_frame",
    height = 770,
    minimal_width = 412,
    padding = 0
}

styles.ctron_settings_scroll_style = {
    type = "scroll_pane_style",
    parent = "scroll_pane",
    height = 770,
}

styles.ctron_settings_table_style = {
    type = "table_style",
    parent = "table",
    minimal_width = 400,
    horizontal_spacing = 0,
    vertical_spacing = 0,
}

styles.ctron_settings_label_style = {
    type = "label_style",
    parent = "frame_title",
    width = 200,
    horizontal_align = "right",
    right_padding = 20
}

styles.ctron_settings_textfield_style = {
    type = "textbox_style",
    parent = "textbox",
    width = 200,
    horizontal_align = "left",
}

styles.ctron_settings_dropdown_style = {
    type = "dropdown_style",
    parent = "dropdown",
    height = 24,
    width = 200,
    top_padding = -4,
    left_padding = 8,
    right_padding = 2,
    button_style = {
        type = "button_style",
        parent = "ctron_frame_button_style",
    },
    list_box_style = {
        type = "list_box_style",
        item_style = {
            type = "button_style",
            parent = "ctron_frame_button_style"
        }
    }
}

--===========================================================================--
-- Job GUI - Styles
--===========================================================================--

styles.ctron_job_inner_frame_style = {
    type = "frame_style",
    parent = "inside_deep_frame",
    height = 770,
    width = 700,
    top_padding = 0,
}

styles.ctron_job_left_pane_style = {
    type = "frame_style",
    parent = "entity_frame",
    height = 770,
    width = 271
}

styles.ctron_minimap_style = {
    type = "minimap_style",
    parent = "minimap",
    height = 250,
    width = 250
}

styles.ctron_job_right_pane_style = {
    type = "frame_style",
    parent = "entity_frame",
    height = 770,
}

styles.ctron_ammo_table_style = {
    type = "table_style",
    parent = "table",
    width = 130,
    horizontal_spacing = 0,
    vertical_spacing = 0
}

styles.ctron_inventory_table_style = {
    type = "table_style",
    parent = "table",
    horizontal_spacing = 0,
    vertical_spacing = 0
}

styles.ctron_trash_table_style = {
    type = "table_style",
    parent = "table",
    horizontal_spacing = 0,
    vertical_spacing = 0
}

styles.ctron_logistic_table_style = {
    type = "table_style",
    parent = "filter_slot_table",
    horizontal_spacing = 0,
    vertical_spacing = 0
}

--===========================================================================--
-- Cargo GUI - Styles
--===========================================================================--

styles.ctron_cargo_scroll_style = {
    type = "scroll_pane_style",
    -- parent = "inner_frame_scroll_pane",
}

styles.ctron_station_label_style = {
    type = "label_style",
    parent = "frame_title",
}

styles.ctron_slot_button = {
    type = "button_style",
    parent = "slot_button",
    horizontal_spacing = 0,
    vertical_spacing = 0
}

styles.ctron_slot_button_selected = {
    type = "button_style",
    parent = "slot_button",
    horizontal_spacing = 0,
    vertical_spacing = 0,
    default_graphical_set = {
        base = { position = { 369, 17 }, corner_size = 8 },
        shadow = { position = { 440, 24 }, corner_size = 8, draw_type = "outer" },
    },
}

styles.ctron_cargo_textfield_style = {
    type = "textbox_style",
    parent = "textbox",
    width = 100,
}

styles.ctron_cargo_flow_style = {
    type = "horizontal_flow_style",
    width = 30,
    height = 30,
}

styles.ctron_cargo_widget_style = {
    type = "empty_widget_style",
    maximal_width = 25,
    horizontally_stretchable = "on"
}

styles.ctron_cargo_item_label_style = {
    type = "label_style",
    font = "item-count",
    top_padding = 15
}

styles.ctron_cargo_label_frame_style = {
    type = "frame_style",
    parent = "inside_deep_frame",
    padding = 0,
    horizontal_align = "center",
}

styles.ctron_cargo_label_style = {
    type = "label_style",
    parent = "frame_title",
    width = 180,
    horizontal_align = "center",
    vertical_align = "center"
}