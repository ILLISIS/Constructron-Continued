local util_func = require("script/utility_functions")

local gui_cargo = {}

function gui_cargo.buildCargoGui(player, surface)
    local cargo_window = player.gui.screen.add{
        type="frame",
        name="ctron_cargo_window",
        direction = "vertical",
        tags = {
            mod = "constructron"
        }
    }
    cargo_window.auto_center = true

    gui_cargo.buildCargoTitleBar(player, surface, cargo_window)

    local cargo_inner_frame = cargo_window.add{
        type = "frame",
        name = "cargo_inner_frame",
        style = "b_inner_frame",
        direction = "vertical"
    }
    cargo_inner_frame.style.width = 430
    cargo_inner_frame.style.maximal_width = 440
    cargo_inner_frame.style.padding = 0

    local cargo_scroll = cargo_inner_frame.add{
        type = "scroll-pane",
        name = "ctron_cargo_scroll",
        direction = "vertical"
    }
    cargo_scroll.style.height = 500
    -- cargo_scroll.style.width = 430
    cargo_scroll.style.vertically_stretchable = "stretch_and_expand"
    cargo_scroll.style.padding = 0
    -- cargo_scroll.style.top_padding = 6
    cargo_scroll.style.extra_padding_when_activated = 0

    gui_cargo.buildCargoContent(player, surface, cargo_scroll)
    global.user_interface[player.index]["cargo_ui"]["elements"].cargo_content = cargo_scroll

    local flow = cargo_window.add{
        type = "flow",
        name = "ctron_cargo_flow",
        direction = "horizontal",
    }
    flow.style.horizontally_stretchable = "stretch_and_expand"
    flow.style.horizontal_align = "center"
    flow.style.vertical_align = "center"

    -- min field
    global.user_interface[player.index]["cargo_ui"]["elements"].min_field = flow.add{
        type = "textfield",
        text = "0",
        style = "ctron_cargo_textfield_style",
        tooltip = {"ctron_gui_locale.min_text_field_tooltip"},
        numeric = true,
        allow_negative = false,
        allow_decimal = false,
        enabled = false,
        tags = {
            mod = "constructron",
        }
    }

    -- max field
    global.user_interface[player.index]["cargo_ui"]["elements"].max_field = flow.add{
        type = "textfield",
        text = "0",
        style = "ctron_cargo_textfield_style",
        tooltip = {"ctron_gui_locale.max_text_field_tooltip"},
        numeric = true,
        allow_negative = false,
        allow_decimal = false,
        enabled = false,
        tags = {
            mod = "constructron",
        }
    }

    -- confirm button
    global.user_interface[player.index]["cargo_ui"]["elements"].confirm_button = flow.add{
        type = "button",
        caption = "confirm",
        style = "ctron_frame_button_style",
        tags = {
            mod = "constructron",
            on_gui_click = "confirm_cargo",
        },
        enabled = false
    }
end


--===========================================================================--
-- Title Section
--===========================================================================--

function gui_cargo.buildCargoTitleBar(player, surface, frame)
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
        caption = {"ctron_gui_locale.cargo_title"},
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
    global.user_interface[player.index].cargo_ui.elements["surface_selector"] = bar.add{
        type = "drop-down",
        name = "surface_select",
        style = "ctron_surface_dropdown_style",
        selected_index = surface.index,
        items = surfaces,
        tags = {
            mod = "constructron",
            on_gui_selection_state_changed = "selected_new_surface",
            surface_selector = "cargo_selector"
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
        name = "close_cargo_window",
        style = "frame_action_button",
        sprite = "utility/close_white",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        mouse_button_filter = {"left"},
        tags = {
            mod = "constructron",
            on_gui_click = "close_cargo_window"
        }
    }
end

--===========================================================================--
-- Cargo Automation Content Section
--===========================================================================--

--function to create a station card with cargo slots
function gui_cargo.buildStationCard(player, surface, frame, station)
    local station_unit_number = station.unit_number
    local card = frame.add{
        type = "frame",
        name = "ctron_station_card_" .. station_unit_number,
        direction = "vertical",
        tags = {
            mod = "constructron",
            station_unit_number = station_unit_number
        }
    }
    card.style.width = 428

    local station_flow = card.add{
        type = "flow",
        direction = "horizontal"
    }

    -- station name
    station_flow.add{
        type = "label",
        style = "ctron_station_label_style",
        caption = "Service Station: "
    }

    local label_frame = station_flow.add{
        type = "frame",
        style = "ctron_cargo_label_frame_style",
        direction = "vertical"
    }

    -- add station backer name
    label_frame.add{
        type = "label",
        caption = station.backer_name,
        style = "ctron_cargo_label_style"
    }

    -- cargo display
    local logistic_scroll_pane = card.add{
        type = "scroll-pane",
        direction = "vertical"
    }

    -- label
    logistic_scroll_pane.add{
        type = "label",
        caption = {"ctron_gui_locale.cargo_requests_label"},
    }

    local logistic_inner_frame = logistic_scroll_pane.add{
        type = "frame",
        style = "inside_deep_frame",
        direction = "vertical"
    }
    logistic_inner_frame.style.width = 400

    local logistic_table = logistic_inner_frame.add{
        type = "table",
        name = "ctron_logistic_table",
        style = "ctron_logistic_table_style",
        column_count = 10,
    }
    logistic_table.style.width = 400

    local request_count = #global.station_requests[station_unit_number] or 1
    -- Round up to the nearest 10
    local logistic_slot_count = math.ceil(request_count / 10) * 10
    if request_count == logistic_slot_count then
        logistic_slot_count = logistic_slot_count + 10
    end
    for i = 1, logistic_slot_count do
        if global.station_requests[station_unit_number][i] then
        local request = global.station_requests[station_unit_number][i]
        local button = logistic_table.add{
                type = "choose-elem-button",
                name = "ctron_request_slot_" .. i,
                elem_type = "item",
                item = request.item,
                tags = {
                    mod = "constructron",
                    on_gui_elem_changed = "on_gui_elem_changed",
                    station_unit_number = station_unit_number,
                    slot_number = i
                }
            }
            -- add flow to button
            local flow = button.add{
                type = "flow",
                name = "ctron_cargo_flow_" .. i,
                style = "ctron_cargo_flow_style",
                direction = "horizontal",
                ignored_by_interaction = true
            }
            -- add label to flow
            flow.add{
                type = "empty-widget",
                style = "ctron_cargo_widget_style",
            }
            -- add item count label
            flow.add{
                type = "label",
                name = "ctron_cargo_content_label" .. i,
                style = "ctron_cargo_item_label_style",
                caption = util_func.number(request.max, true)
            }
            local logistic_ui_elements = global.user_interface[player.index]["cargo_ui"]["elements"]
            logistic_ui_elements[station_unit_number] = logistic_ui_elements[station_unit_number] or {}
            logistic_ui_elements[station_unit_number][button.name] = button
        else
            local button = logistic_table.add{
                type = "choose-elem-button",
                name = "ctron_request_slot_" .. i,
                elem_type = "item",
                tags = {
                    mod = "constructron",
                    on_gui_elem_changed = "on_gui_elem_changed",
                    station_unit_number = station_unit_number,
                    slot_number = i
                }
            }
            local logistic_ui_elements = global.user_interface[player.index]["cargo_ui"]["elements"]
            logistic_ui_elements[station_unit_number] = logistic_ui_elements[station_unit_number] or {}
            logistic_ui_elements[station_unit_number][button.name] = button
        end
    end
end

function gui_cargo.buildCargoContent(player, surface, frame)
    local surface_index = game.surfaces[global.user_interface[player.index].cargo_ui.elements["surface_selector"].selected_index].index
    for _, station in pairs(global.service_stations) do
        if station.surface.index == surface_index then
            gui_cargo.buildStationCard(player, surface, frame, station)
        end
    end
end

return gui_cargo