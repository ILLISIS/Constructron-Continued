local gui_settings = {}


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
    settings_inner_frame.style.horizontally_stretchable = "on"

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
    }
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
    for _, iterated_surface in pairs(game.surfaces) do
        surfaces[#surfaces+1] = iterated_surface.name
    end
    global.user_interface[player.index].settings_ui.elements["surface_selector"] = bar.add{
        type = "drop-down",
        name = "surface_select",
        style = "ctron_surface_dropdown_style",
        selected_index = surface.index,
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
        sprite = "utility/close_white",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
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
    local surface_index = game.surfaces[global.user_interface[player.index].settings_ui.elements["surface_selector"].selected_index].index

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
        text = (global.job_start_delay / 60),
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

    -- entities per second
    global_settings_table.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_entities_per_second_label"},
        style = "ctron_settings_label_style"
    }
    global_settings_table.add{
        type = "textfield",
        text = global.entities_per_second,
        style = "ctron_settings_textfield_style",
        tooltip = {"ctron_gui_locale.settings_entities_per_second_tooltip"},
        numeric = true,
        allow_negative = false,
        allow_decimal = true,
        tags = {
            mod = "constructron",
            on_gui_text_changed = "change_entities_per_second"
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
        state = global.horde_mode,
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
    hflow.style.horizontally_stretchable = "on"

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
    spacer_1.style.horizontally_stretchable = "on"

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

    local table = frame.add{
        type = "table",
        name = "ctron_surface_settings_table",
        style = "ctron_settings_table_style",
        column_count = 2,
    }

    -- robot count
    table.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_robot_count_label"},
        style = "ctron_settings_label_style"
    }
    table.add{
        type = "textfield",
        text = global.desired_robot_count[surface_index],
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
    local robots = {}
    local selected_robot_index = 1
    for _, robot in pairs(game.get_filtered_entity_prototypes{{filter = "type", type = "construction-robot"}}) do
        robots[#robots+1] = robot.name
        if robot.name == global.desired_robot_name[surface_index] then
            selected_robot_index = #robots
        end
    end
    table.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_robot_selection_label"},
        style = "ctron_settings_label_style"
    }
    table.add{
        type = "drop-down",
        name = "ctron_robot_select",
        style = "ctron_settings_dropdown_style",
        tooltip = {"ctron_gui_locale.settings_robot_selection_tooltip"},
        selected_index = selected_robot_index,
        items = robots,
        tags = {
            mod = "constructron",
            on_gui_selection_state_changed = "select_new_robot",
            setting_surface = surface_index
        }
    }

    -- job toggles
    for setting_name, setting_params in pairs(toggle_settings) do
        table.add{
            type = "label",
            caption = setting_params.label,
            style = "ctron_settings_label_style"
        }
        table.add{
            type = "checkbox",
            name = "ctron_" .. setting_name .. "_toggle",
            state = global[setting_name .. "_job_toggle"][surface_index],
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
    local ammo_list = {}
    local ammo_prototypes = game.get_filtered_item_prototypes{{filter = "type", type = "ammo"}}
    local selected_ammo_index = 1
    for _, ammo in pairs(ammo_prototypes) do
        local ammo_type = ammo.get_ammo_type() or {}
        if ammo_type.category == "rocket" then
            ammo_list[#ammo_list+1] = ammo.name
            if ammo.name == global.ammo_name[surface_index] then
                selected_ammo_index = #ammo_list
            end
        end
    end
    table.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_ammo_selection_label"},
        style = "ctron_settings_label_style"
    }
    table.add{
        type = "drop-down",
        name = "ctron_ammo_select",
        style = "ctron_settings_dropdown_style",
        tooltip = {"ctron_gui_locale.settings_ammo_selection_tooltip"},
        selected_index = selected_ammo_index,
        items = ammo_list,
        tags = {
            mod = "constructron",
            on_gui_selection_state_changed = "selected_new_ammo",
            setting_surface = surface_index
        }
    }

    -- ammo count
    table.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_ammo_count_label"},
        style = "ctron_settings_label_style"
    }
    table.add{
        type = "textfield",
        text = global.ammo_count[surface_index],
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
    table.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_repair_jobs_label"},
        style = "ctron_settings_label_style"
    }
    table.add{
        type = "checkbox",
        name = "ctron_repair_toggle",
        state = global.repair_job_toggle[surface_index],
        tooltip = {"ctron_gui_locale.settings_repair_jobs_tooltip"},
        tags = {
            mod = "constructron",
            on_gui_checked_state_changed = "toggle_job_setting",
            setting = "repair",
            setting_surface = surface_index
        }
    }

    -- repair tool selection
    local repair_items = {}
    local repair_prototypes = game.get_filtered_item_prototypes{{filter = "type", type = "repair-tool"}}
    local selected_repair_index = 1
    for _, repair_item in pairs(repair_prototypes) do
        repair_items[#repair_items+1] = repair_item.name
        if repair_item.name == global.repair_tool_name[surface_index] then
            selected_repair_index = #repair_items
        end
    end
    table.add{
        type = "label",
        caption = {"ctron_gui_locale.settings_repair_tool_selection_label"},
        style = "ctron_settings_label_style"
    }
    table.add{
        type = "drop-down",
        name = "ctron_repair_selector",
        style = "ctron_settings_dropdown_style",
        tooltip = {"ctron_gui_locale.settings_repair_tool_selection_tooltip"},
        selected_index = selected_repair_index,
        items = repair_items,
        tags = {
            mod = "constructron",
            on_gui_selection_state_changed = "selected_new_repair_tool",
            setting_surface = surface_index
        }
    }
end

return gui_settings