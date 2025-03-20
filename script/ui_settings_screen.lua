local gui_settings = {}

---comment
---@param player LuaPlayer
---@param surface LuaSurface
function gui_settings.buildSettingsGui(player, surface)
    local settings_window = player.gui.screen.add{
        type="frame",
        name="ctron_settings_window",
        direction = "vertical",
        tags = {
            mod = "constructron"
        }
    }
    settings_window.auto_center = true

    gui_settings.buildSettingsTitleBar(player, surface, settings_window)

    local settings_inner_frame = settings_window.add{
        type = "frame",
        name = "ctron_settings_inner_frame",
        style = "ctron_settings_inner_frame_style",
        direction = "vertical"
    }
    settings_inner_frame.style.horizontally_stretchable = true

    local settings_scroll = settings_inner_frame.add{
        type = "scroll-pane",
        name = "ctron_settings_scroll",
        style = "ctron_settings_scroll_style",
        direction = "vertical"
    }

    gui_settings.buildSettingsContent(player, surface, settings_scroll)
end

local toggle_settings = {
    ["construction"] = {
        label = {"ctron_gui_locale.settings_construction_jobs_label"},
        tooltip = {"ctron_gui_locale.settings_construction_jobs_tooltip"}
    },
    ["deconstruction"] = {
        label = {"ctron_gui_locale.settings_deconstruction_jobs_label"},
        tooltip = {"ctron_gui_locale.settings_deconstruction_jobs_tooltip"}
    },
    ["rebuild"] = {
        label = {"ctron_gui_locale.settings_rebuild_jobs_label"},
        tooltip = {"ctron_gui_locale.settings_rebuild_jobs_tooltip"}
    },
    ["upgrade"] = {
        label = {"ctron_gui_locale.settings_upgrade_jobs_label"},
        tooltip = {"ctron_gui_locale.settings_upgrade_jobs_tooltip"}
    },
    ["destroy"] = {
        label = {"ctron_gui_locale.settings_destroy_jobs_label"},
        tooltip = {"ctron_gui_locale.settings_destroy_jobs_tooltip"}
    },
    ["zone_restriction"] = {
        label = {"ctron_gui_locale.settings_zone_restriction_label"},
        tooltip = {"ctron_gui_locale.settings_zone_restriction_tooltip"}
    },
}

--===========================================================================--
-- Title Section
--===========================================================================--

function gui_settings.buildSettingsTitleBar(player, surface, frame)
    local bar = frame.add{
        type = "flow",
        name = "ctron_title_bar",
        style = "ctron_title_bar_flow_style",
        drag_target = frame
    }

    -- title
    bar.add{
        type = "label",
        style = "frame_title",
        caption = {"ctron_gui_locale.settings_title"},
        ignored_by_interaction = true
    }

    -- drag area
    local title_bar = bar.add{
        type = "empty-widget",
        style = "ctron_title_bar_drag_bar_style",
    }
    title_bar.drag_target = frame

    -- surface selection
    local surfaces = {}
    local selected_index
    for _, surface_name in pairs(storage.managed_surfaces) do
        surfaces[#surfaces+1] = surface_name
        if surface_name == surface.name then
            selected_index = #surfaces
        end
    end
    if not storage.managed_surfaces[surface.index] then
        surfaces[#surfaces+1] = surface.name
        selected_index = #surfaces
    end
    storage.user_interface[player.index].settings_ui.elements["surface_selector"] = bar.add{
        type = "drop-down",
        name = "surface_select",
        style = "ctron_surface_dropdown_style",
        selected_index = selected_index,
        tooltip = {"ctron_gui_locale.surface_selector_tooltip"},
        items = surfaces,
        tags = {
            mod = "constructron",
            on_gui_selection_state_changed = "selected_new_surface",
            surface_selector = "ctron_settings"
        }
    }

    -- seperator line
    local seperator = bar.add{
        type = "line",
        direction = "vertical",
        ignored_by_interaction = true
    }
    seperator.style.height = 24

    -- close button
    bar.add{
        type = "sprite-button",
        name = "close_settings_window",
        style = "frame_action_button",
        sprite = "utility/close",
        mouse_button_filter = {"left"},
        tags = {
            mod = "constructron",
            on_gui_click = "close_settings_window"
        }
    }
end

--===========================================================================--
-- Settings Content Section
--===========================================================================--

function gui_settings.buildSettingsContent(player, surface, frame)
    local surface_index = game.surfaces[storage.user_interface[player.index].settings_ui.elements["surface_selector"].selected_index].index

    -- global settings

    frame.add{
        type = "line",
        direction = "horizontal",
        ignored_by_interaction = true
    }

    local global_settings_label = frame.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_global_settings_label"},
    }
    global_settings_label.style.left_padding = 12

    frame.add{
        type = "line",
        direction = "horizontal",
        ignored_by_interaction = true
    }

    local global_settings_table = frame.add{
        type = "table",
        name = "ctron_global_settings_table",
        style = "ctron_settings_table_style",
        column_count = 2,
    }

    -- job start delay
    global_settings_table.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_job_start_delay_label"},
        style = "ctron_settings_label_style"
    }
    global_settings_table.add{
        type = "textfield",
        text = (storage.job_start_delay / 60),
        style = "ctron_settings_textfield_style",
        tooltip = {"ctron_gui_locale.settings_job_start_delay_tooltip"},
        numeric = true,
        allow_negative = false,
        allow_decimal = true,
        tags = {
            mod = "constructron",
            on_gui_text_changed = "change_job_start_delay"
        }
    }

    -- horde mode
    global_settings_table.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_horde_mode_label"},
        style = "ctron_settings_label_style"
    }
    global_settings_table.add{
        type = "checkbox",
        name = "ctron_horde_toggle",
        state = storage.horde_mode,
        tooltip = {"ctron_gui_locale.settings_horde_mode_tooltip"},
        tags = {
            mod = "constructron",
            on_gui_checked_state_changed = "toggle_horde_mode"
        }
    }

    -- per surface settings

    frame.add{
        type = "line",
        direction = "horizontal",
        ignored_by_interaction = true
    }

    local hflow = frame.add{
        type = "flow",
        name = "ctron_settings_surface_flow",
        direction = "horizontal"
    }
    hflow.style.horizontally_stretchable = true

    local surface_label = hflow.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_surface_specific_label"},
    }
    surface_label.style.left_padding = 12
    -- surface_label.style.width = 300

    local spacer_1 = hflow.add{
        type = "empty-widget",
        name = "ctron_spacer_1",
        ignored_by_interaction = true
    }
    spacer_1.style.horizontally_stretchable = true

    -- button
    local apply_button = hflow.add{
        type = "button",
        name = "ctron_apply_button",
        caption = {"ctron_gui_locale.settings_apply_button"},
        style = "ctron_frame_button_style",
        tooltip = {"ctron_gui_locale.settings_apply_button_tooltip"},
        tags = {
            mod = "constructron",
            on_gui_click = "apply_settings_template",
            setting_surface = surface_index
        },
    }
    apply_button.style.right_margin = 12

    frame.add{
        type = "line",
        direction = "horizontal",
        ignored_by_interaction = true
    }

    local settings_table = frame.add{
        type = "table",
        name = "ctron_surface_settings_table",
        style = "ctron_settings_table_style",
        column_count = 2,
    }

    -- robot count
    settings_table.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_robot_count_label"},
        style = "ctron_settings_label_style"
    }
    settings_table.add{
        type = "textfield",
        text = storage.desired_robot_count[surface_index],
        style = "ctron_settings_textfield_style",
        tooltip = {"ctron_gui_locale.settings_robot_count_tooltip"},
        numeric = true,
        allow_negative = false,
        allow_decimal = false,
        tags = {
            mod = "constructron",
            on_gui_text_changed = "change_robot_count",
            setting_surface = surface_index
        }
    }
    -- robot selection
    settings_table.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_robot_selection_label"},
        tooltip = {"ctron_gui_locale.settings_robot_selection_tooltip"},
        style = "ctron_settings_label_style"
    }

    local robot_items = {}
    for _, robot in pairs(prototypes.get_entity_filtered{{filter = "type", type = "construction-robot"}}) do
        if robot.items_to_place_this ~= nil and robot.items_to_place_this[1] and robot.items_to_place_this[1].name then
            local item = robot.items_to_place_this[1]
            table.insert(robot_items, item.name)
        end
    end
    settings_table.add{
        type = "choose-elem-button",
        elem_type = "item-with-quality",
        ["item-with-quality"] = storage.desired_robot_name[surface_index],
        elem_filters = {{filter = "name", name = robot_items}},
        tags = {
            mod = "constructron",
            on_gui_elem_changed = "select_new_robot",
            setting_surface = surface_index
        }
    }

    -- job toggles
    for setting_name, setting_params in pairs(toggle_settings) do
        settings_table.add{
            type = "label",
            caption = setting_params.label,
            style = "ctron_settings_label_style"
        }
        settings_table.add{
            type = "checkbox",
            name = "ctron_" .. setting_name .. "_toggle",
            state = storage[setting_name .. "_job_toggle"][surface_index],
            tooltip = setting_params.tooltip,
            tags = {
                mod = "constructron",
                on_gui_checked_state_changed = "toggle_job_setting",
                setting = setting_name,
                setting_surface = surface_index
            }
        }
    end

    -- ammo selection
    settings_table.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_ammo_selection_label"},
        style = "ctron_settings_label_style"
    }
    settings_table.add{
        type = "choose-elem-button",
        name = "ctron_ammo_select",
        elem_type = "item-with-quality",
        ["item-with-quality"] = storage.ammo_name[surface_index],
        elem_filters = {{filter = "type", type = "ammo"}},
        tags = {
            mod = "constructron",
            on_gui_elem_changed = "selected_new_ammo",
            setting_surface = surface_index
        }
    }

    -- ammo count
    settings_table.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_ammo_count_label"},
        style = "ctron_settings_label_style"
    }
    settings_table.add{
        type = "textfield",
        text = storage.ammo_count[surface_index],
        style = "ctron_settings_textfield_style",
        tooltip = {"ctron_gui_locale.settings_ammo_count_tooltip"},
        numeric = true,
        allow_negative = false,
        allow_decimal = false,
        tags = {
            mod = "constructron",
            on_gui_text_changed = "change_ammo_count",
            setting_surface = surface_index
        }
    }

    -- repair job toggle
    settings_table.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_repair_jobs_label"},
        style = "ctron_settings_label_style"
    }
    settings_table.add{
        type = "checkbox",
        name = "ctron_repair_toggle",
        state = storage.repair_job_toggle[surface_index],
        tooltip = {"ctron_gui_locale.settings_repair_jobs_tooltip"},
        tags = {
            mod = "constructron",
            on_gui_checked_state_changed = "toggle_job_setting",
            setting = "repair",
            setting_surface = surface_index
        }
    }

    -- repair tool selection
    settings_table.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_repair_tool_selection_label"},
        style = "ctron_settings_label_style"
    }
    settings_table.add{
        type = "choose-elem-button",
        -- style = "",
        elem_type = "item-with-quality",
        ["item-with-quality"] = storage.repair_tool_name[surface_index],
        elem_filters = {{filter = "name", name = "repair-pack"}},
        tags = {
            mod = "constructron",
            on_gui_elem_changed = "selected_new_repair_tool",
            setting_surface = surface_index
        }
    }
end

return gui_settings