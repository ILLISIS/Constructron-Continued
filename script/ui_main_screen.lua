color_lib = require("script/color_lib")

local gui_main = {}

function gui_main.buildMainGui(player)
    local main_window = player.gui.screen.add{
        type="frame",
        name="ctron_main_window",
        direction = "vertical",
        tags = {
            mod = "constructron",
            on_gui_closed = "on_gui_closed"
        }
    }
    player.opened = main_window
    main_window.auto_center = true
    -- build subsections
    local surface = player.surface
    gui_main.buildMainTitleBar(player, surface, main_window)
    local outer_main_flow = main_window.add{
        type = "flow",
        direction = "horizontal"
    }
    local main_flow = outer_main_flow.add{
        type = "flow",
        direction = "horizontal"
    }
    outer_main_flow.style.horizontally_stretchable = true

    gui_main.buildStatsSection(player, surface, main_flow)
    local outer_control_flow = outer_main_flow.add{
        type = "flow",
        direction = "horizontal"
    }
    local control_flow = outer_control_flow.add{
        type = "flow",
        direction = "horizontal"
    }
    outer_control_flow.style.horizontally_stretchable = true
    outer_control_flow.style.vertically_stretchable = true
    outer_control_flow.style.horizontal_align = "right"
    outer_control_flow.style.vertical_align = "bottom"

    control_flow.add{
        type = "button",
        style = "ctron_frame_button_style",
        caption = {"ctron_gui_locale.cargo_jobs_button"},
        mouse_button_filter = {"left"},
        tags = {
            mod = "constructron",
            on_gui_click = "open_cargo_window"
        }
    }

    control_flow.add{
        type = "button",
        style = "ctron_frame_button_style",
        caption = {"ctron_gui_locale.all_logistics_button"},
        mouse_button_filter = {"left"},
        tags = {
            mod = "constructron",
            on_gui_click = "open_logistics_window"
        }
    }
    gui_main.buildMainContent(player, surface, main_window)
end

--===========================================================================--
-- Title Section
--===========================================================================--

function gui_main.buildMainTitleBar(player, surface, frame)
    local bar = frame.add{
        type = "flow",
        name = "ctron_title_bar",
        style = "ctron_title_bar_flow_style"
    }
    bar.drag_target = frame

    -- title
    bar.add{
        type = "label",
        style = "frame_title",
        caption = {"ctron_gui_locale.main_title"},
        ignored_by_interaction = true
    }

    -- drag area
    bar.add{
        type = "empty-widget",
        style = "ctron_title_bar_drag_bar_style",
        ignored_by_interaction = true
    }

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
    storage.user_interface[player.index].main_ui.elements["surface_selector"] = bar.add{
        type = "drop-down",
        name = "surface_select",
        style = "ctron_surface_dropdown_style",
        selected_index = selected_index,
        tooltip = {"ctron_gui_locale.surface_selector_tooltip"},
        items = surfaces,
        tags = {
            mod = "constructron",
            on_gui_selection_state_changed = "selected_new_surface",
            surface_selector = "ctron_main"
        }
    }

    -- debug button
    local debug_button = {
        type = "button",
        name = "ctron_debug_button",
        style = "ctron_frame_button_style",
        mouse_button_filter = {"left"},
        tooltip = {"ctron_gui_locale.debug_button_tooltip"},
        tags = {
            mod = "constructron",
            on_gui_click = "toggle_debug_mode"
        }
    }
    if storage.debug_toggle then
        debug_button.caption = {"ctron_gui_locale.debug_button_on"}
    else
        debug_button.caption = {"ctron_gui_locale.debug_button_off"}
    end
    bar.add(debug_button)

    -- settings button
    bar.add{
        type = "button",
        name = "ctron_settings_button",
        style = "ctron_frame_button_style",
        caption = {"ctron_gui_locale.settings"},
        mouse_button_filter = {"left"},
        tags = {
            mod = "constructron",
            on_gui_click = "open_settings_window"
        }
    }

    -- seperator line
    local seperator_line = bar.add{
        type = "line",
        direction = "vertical",
        ignored_by_interaction = true
    }
    seperator_line.style.height = 24

    -- close button
    bar.add{
        type = "sprite-button",
        name = "ctron_close_main_gui",
        style = "frame_action_button",
        sprite = "utility/close",
        mouse_button_filter = {"left"},
        tags = {
            mod = "constructron",
            on_gui_click = "close_main_window"
        }
    }
end

--===========================================================================--
-- Stats Section
--===========================================================================--

function gui_main.buildStatsSection(player, surface, frame)
    local stats_section = frame.add{
        type = "flow",
        name = "ctron_stats_section",
        direction = "horizontal"
    }
    gui_main.create_stat_card(player, surface, stats_section, {"ctron_gui_locale.stat_total_constructrons"}, "total", storage.constructrons_count[surface.index])
    gui_main.create_stat_card(player, surface, stats_section, {"ctron_gui_locale.stat_available_constructrons"}, "available", storage.available_ctron_count[surface.index])
end

function gui_main.create_stat_card(player, surface, frame, caption, stat, value)
    -- stats card
    local card = frame.add{
        type = "frame",
        name = "ctron_stat_card_" .. stat,
        style = "ctron_stat_card_style",
        direction = "vertical"
    }

    -- Total Constructrons stat card
    card.add{
        type = "label",
        name = "ctron_stat_label",
        caption = caption,
        style = "ctron_stat_card_label_style"
    }

    -- Available Constructrons stat card
    storage.user_interface[player.index].main_ui.elements[stat] = card.add{
        type = "label",
        name = "ctron_job_value_label",
        caption = value,
        style = "ctron_stat_card_label_style"
    }
end

--===========================================================================--
-- Main Content Section
--===========================================================================--

function gui_main.buildMainContent(player, surface, main_window)
    -- main content frame
    local main_content_frame = main_window.add{
        type = "frame",
        name = "ctron_main_content_frame",
        style = "ctron_main_content_style",
        direction = "vertical"
    }

    -- main scroll section
    local main_scroll_section = main_content_frame.add{
        type = "scroll-pane",
        name = "job_scroll_pane",
        style = "ctron_main_scroll_section_style",
        direction = "vertical"
    }

    gui_main.create_job_sections(player, surface, main_scroll_section)
end

local inprogress_job_states = {
    ["setup"] = true,
    ["starting"] = true,
    ["in_progress"] = true,
    ["robot_collection"] = true
}

local job_types = {
    "deconstruction",
    "construction",
    "upgrade",
    "repair",
    "destroy",
    "cargo"
}

local job_colors = {
    ["deconstruction"] = color_lib.colors.red,
    ["construction"] = color_lib.colors.blue,
    ["upgrade"] = color_lib.colors.green,
    ["repair"] = color_lib.colors.purple,
    ["destroy"] = color_lib.colors.black,
    ["cargo"] = color_lib.colors.gray
}

function gui_main.empty_section_check(section)
    local number_of_children = #section.children
    if number_of_children > 1 then
        for _, child in pairs(section.children) do
            if child.name == "ctron_no_jobs_card" then
                child.destroy()
            end
        end
        return
    elseif number_of_children == 1 then
        return
    end

    -- add the no job card
    local card = section.add{
        type = "frame",
        name = "ctron_no_jobs_card",
        style = "ctron_job_card_style",
        tags = {
            mod = "constructron",
            no_jobs = true
        },
    }

    local spacer_1 = card.add{
        type = "empty-widget",
        name = "ctron_spacer_1",
        ignored_by_interaction = true
    }
    spacer_1.style.horizontally_stretchable = true

    card.add{
        type = "label",
        name = "ctron_no_jobs_label",
        caption = {"ctron_gui_locale.main_no_jobs_label"},
        -- style = "ctron_no_jobs_label_style"
    }

    local spacer_2 = card.add{
        type = "empty-widget",
        name = "ctron_spacer_2",
        ignored_by_interaction = true
    }
    spacer_2.style.horizontally_stretchable = true
end

function gui_main.create_job_sections(player, surface, frame)
    -- create job sections
    local in_progress_section = gui_main.create_job_section(player, surface, frame, "in_progress_section", {"ctron_gui_locale.inprogress_section_name"})
    local finishing_section = gui_main.create_job_section(player, surface, frame, "finishing_section", {"ctron_gui_locale.finishing_section_name"})
    local pending_section = gui_main.create_job_section(player, surface, frame, "pending_section", {"ctron_gui_locale.pending_section_name"})
    pending_section.style.vertically_stretchable = true

    -- populate job sections with job cards
    for _, job in pairs(storage.jobs) do
        if job.surface_index == surface.index then
            if inprogress_job_states[job.state] then
                gui_main.create_job_card(job, in_progress_section)
            elseif job.state == "finishing" then
                gui_main.create_job_card(job, finishing_section)
            end
        end
    end
    gui_main.empty_section_check(in_progress_section)
    gui_main.empty_section_check(finishing_section)

    -- populate pending section with chunk cards
    for _, job_type in pairs(job_types) do
        for _, chunk in pairs(storage[job_type .. '_queue'][surface.index]) do
            gui_main.create_chunk_card(chunk, surface.index, pending_section, job_type)
        end
    end
    gui_main.empty_section_check(pending_section)
end

function gui_main.create_job_section(player, surface, frame, section_name, caption_name)
    local section = frame.add{
        type = "frame",
        name = "ctron_" .. section_name,
        style = "ctron_job_status_section_style", -- TODO: this is a shared style, should this be a new one?
        direction = "vertical",
    }

    -- section title bar
    local flow = section.add{
        type = "flow",
        name = "ctron_section_flow",
        direction = "horizontal",
        style = "ctron_job_status_section_flow_style"
    }
    flow.style.top_padding = 2

    flow.add{
        type = "empty-widget",
        name = "ctron_spacer_1",
        style = "ctron_job_section_title_bar_style", -- TODO: this is a shared style, should this be a new one?
        ignored_by_interaction = true,
    }

    -- section title
    flow.add{
        type = "label",
        name = "ctron_" .. section_name .. "_label",
        caption = caption_name,
        style = "ctron_job_section_label_style",
    }

    -- collapse/expand button
    flow.add{
        type = "sprite-button",
        name = "ctron_collapse_expand_button_" .. section_name,
        style = "ctron_collapse_expand_button_style",
        sprite = "utility/collapse",
        mouse_button_filter = {"left"},
        tags = {
            mod = "constructron",
            on_gui_click = "toggle_section",
            section_name = section_name,
        }
    }

    flow.add{
        type = "empty-widget",
        name = "ctron_spacer_2",
        style = "ctron_job_section_title_bar_style", -- TODO: this is a shared style, should this be a new one?
        ignored_by_interaction = true,
    }

    -- job card section
    storage.user_interface[player.index].main_ui.elements[section_name] = section.add{
        type = "flow",
        name = "ctron_" .. section_name .. "_inner",
        direction = "vertical"
    }
    storage.user_interface[player.index].main_ui.elements[section_name].style.vertical_spacing = 0

    return storage.user_interface[player.index].main_ui.elements[section_name]
end


function gui_main.create_job_card(job, section)
    local job_type = job.job_type
    local job_index = job.job_index

    -- job card
    local job_card = section.add{
        type = "frame",
        name = "ctron_" .. job_type .. "_card_" .. job_index,
        style = "ctron_job_card_style",
        tags = {
            mod = "constructron",
            job_index = job_index
        },
    }

    local card_flow = job_card.add{
        type = "flow",
        direction = "horizontal"
    }
    card_flow.style.vertical_align = "center"
    -- add job_type label
    local label_bg = card_flow.add{
        type = "progressbar",
        value = 1,
    }
    label_bg.style.color = job_colors[job_type]
    label_bg.style.width = 180
    label_bg.style.bar_width = 30 -- bar thickness
    label_bg.add{
        type = "label",
        name = "ctron_job_type_label",
        caption = {"ctron_gui_locale.job_card_" .. job_type .. "_name"},
        style = "ctron_job_type_label_style"
    }

    -- status label
    local status_label = card_flow.add{
        type = "label",
        caption = job.job_status
    }
    status_label.style.left_padding = 10

    card_flow.add{
        type = "empty-widget",
        name = "ctron_spacer",
        style = "ctron_job_section_title_bar_style", -- TODO: this is a shared style, should this be a new one?
        ignored_by_interaction = true
    }

    -- add locate button
    card_flow.add{
        type = "button",
        name = "ctron_locate_button",
        caption = {"ctron_gui_locale.job_locate_button"},
        -- tooltip = {"ctron_gui_locale.job_locate_button_tooltip"},
        style = "ctron_frame_button_style",
        raise_hover_events = true,
        tags = {
            mod = "constructron",
            on_gui_click = "ctron_locate_job",
            on_gui_hover = "on_gui_hover_job",
            on_gui_leave = "on_gui_leave",
            job_index = job_index
        }
    }

    -- add cancel button
    card_flow.add{
        type = "button",
        name = "ctron_cancel_button",
        caption = {"ctron_gui_locale.job_cancel_button"},
        tooltip = {"ctron_gui_locale.job_cancel_button_tooltip"},
        style = "ctron_frame_button_style",
        tags = {
            mod = "constructron",
            on_gui_click = "ctron_cancel_job",
            job_index = job_index
        }
    }

    -- add details button
    card_flow.add{
        type = "button",
        name = "ctron_details_button",
        caption = {"ctron_gui_locale.job_details_button"},
        style = "ctron_frame_button_style",
        tooltip = {"ctron_gui_locale.job_details_button_tooltip"},
        tags = {
            mod = "constructron",
            on_gui_click = "open_job_window",
            job_index = job_index
        }
    }

    gui_main.empty_section_check(section)
end


function gui_main.create_chunk_card(chunk, surface_index, section, job_type)
    local chunk_key = chunk.key or chunk.index

    -- chunk card
    local chunk_card = section.add{
        type = "frame",
        style = "ctron_chunk_card_style",
        tags = {
            mod = "constructron",
            chunk_key = chunk_key,
            job_type = job_type
        }
    }
    local card_flow = chunk_card.add{
        type = "flow",
        direction = "horizontal"
    }
    card_flow.style.vertical_align = "center"
    -- add chunk_type label
    local label_bg = card_flow.add{
        type = "progressbar",
        value = 1,
    }
    label_bg.style.color = job_colors[job_type]
    label_bg.style.width = 180
    label_bg.style.bar_width = 30 -- bar thickness
    label_bg.add{
        type = "label",
        name = "ctron_job_type_label",
        caption = {"ctron_gui_locale.job_card_" .. job_type .. "_name"},
        style = "ctron_job_type_label_style"
    }

    -- status label
    local status_label = card_flow.add{
        type = "label",
        caption = {"ctron_gui_locale.job_status"}
    }
    status_label.style.left_padding = 10

    card_flow.add{
        type = "empty-widget",
        style = "ctron_job_section_title_bar_style",
        ignored_by_interaction = true
    }
    if not (job_type == "cargo") then
        -- add locate button
        card_flow.add{
            type = "button",
            caption = {"ctron_gui_locale.job_locate_button"},
            style = "ctron_frame_button_style",
            raise_hover_events = true,
            tags = {
                mod = "constructron",
                on_gui_click = "ctron_locate_chunk",
                on_gui_hover = "on_gui_hover_chunk",
                on_gui_leave = "on_gui_leave",
                chunk_key = chunk_key,
                surface_index = surface_index,
                job_type = job_type
            }
        }

        -- add cancel button
        card_flow.add{
            type = "button",
            caption = {"ctron_gui_locale.job_cancel_button"},
            style = "ctron_frame_button_style",
            tags = {
                mod = "constructron",
                on_gui_click = "ctron_cancel_chunk",
                chunk_key = chunk_key,
                surface_index = surface_index,
                job_type = job_type
            }
        }
    end

    -- add details button
    -- card.add{
    --     type = "button",
    --     name = "ctron_details_button",
    --     caption = "Details",
    --     style = "ctron_frame_button_style",
    --     tags = {
    --         mod = "constructron",
    --         on_gui_click = "ctron_job_details",
    --         chunk_key = chunk_key,
    --         job_type = job_type
    --     }
    -- }
end

--===========================================================================--
-- Logistics window
--===========================================================================--
--iterate over all jobs on the selected surface and display logistics of the workers
function gui_main.BuildLogisticsDisplay(player, surface)
    local surface_index = surface.index
    local logistics_window = player.gui.screen.add{
        type="frame",
        name="ctron_logistics_window",
        direction = "vertical",
        tags = {
            mod = "constructron",
            on_gui_closed = "on_gui_closed"
        }
    }
    logistics_window.auto_center = true
    logistics_window.style.width = 426
    local bar = logistics_window.add{
        type = "flow",
        name = "ctron_title_bar",
        style = "ctron_title_bar_flow_style"
    }
    bar.drag_target = logistics_window

    -- title
    bar.add{
        type = "label",
        style = "frame_title",
        caption = {"ctron_gui_locale.all_logistics_req"},
        ignored_by_interaction = true
    }

    -- drag area
    bar.add{
        type = "empty-widget",
        style = "ctron_title_bar_drag_bar_style",
        ignored_by_interaction = true
    }

    -- surface selection
    local surfaces = {}
    local selected_index
    for _, surface_name in pairs(storage.managed_surfaces) do
        surfaces[#surfaces+1] = surface_name
        if surface_name == surface.name then
            selected_index = #surfaces
        end
    end
    if not storage.managed_surfaces[surface_index] then
        surfaces[#surfaces+1] = surface.name
        selected_index = #surfaces
    end
    storage.user_interface[player.index].logistics_ui.elements["surface_selector"] = bar.add{
        type = "drop-down",
        name = "surface_select",
        style = "ctron_surface_dropdown_style",
        selected_index = selected_index,
        tooltip = {"ctron_gui_locale.surface_selector_tooltip"},
        items = surfaces,
        tags = {
            mod = "constructron",
            on_gui_selection_state_changed = "selected_new_surface",
            surface_selector = "logistics_selector"
        }
    }

    -- close button
    bar.add{
        type = "sprite-button",
        name = "ctron_close_main_gui",
        style = "frame_action_button",
        sprite = "utility/close",
        mouse_button_filter = {"left"},
        tags = {
            mod = "constructron",
            on_gui_click = "close_logistics_window"
        }
    }
    local content_flow = logistics_window.add{
        type = "flow",
        direction = "vertical"
    }
    storage.user_interface[player.index].logistics_ui.elements["logistics_content"] = content_flow
    gui_main.BuildLogisticsContent(player, surface_index, content_flow)
end

function gui_main.BuildLogisticsContent(player, surface_index, logistics_window)
    -- logistics display
    local logistic_scroll_pane = logistics_window.add{
        type = "scroll-pane",
        name = "ctron_logistic_scroll_pane",
        direction = "vertical"
    }

    local logistics_requests = {}
    local ctron_count = 0
    for _, job in pairs(storage.jobs) do
        if (job.surface_index == surface_index) and job.state == "starting" and job.worker and job.worker.valid then
            local worker = job.worker
            local logistic_point = worker.get_logistic_point(0) ---@cast logistic_point -nil
            local section = logistic_point.get_section(1)
            local flag = false
            for i = 1, #section.filters do
                local slot = section.filters[i]
                if slot.value then
                    local item_name = slot.value.name
                    local quality = slot.value.quality
                    flag = true
                    if logistics_requests[item_name] and logistics_requests[item_name][quality] then
                        logistics_requests[item_name][quality] = logistics_requests[item_name][quality] + slot.max
                    else
                        logistics_requests[item_name] = {
                            [quality] = (slot.max or slot.min)
                        }
                    end
                end
            end
            if flag then
                ctron_count = ctron_count + 1
            end
        end
    end

    -- label
    logistic_scroll_pane.add{
        type = "label",
        caption = {"ctron_gui_locale.logistic_requests_label", ctron_count},
    }

    local logistic_inner_frame = logistic_scroll_pane.add{
        type = "frame",
        style = "inside_deep_frame",
        direction = "vertical"
    }

    local logistic_table = logistic_inner_frame.add{
        type = "table",
        style = "ctron_logistic_table_style",
        column_count = 10,
    }

    for item, value in pairs(logistics_requests) do
        for quality, count in pairs(value) do
            local button = logistic_table.add{
                type = "choose-elem-button",
                elem_type = "item-with-quality",
                ["item-with-quality"] = {name = item, quality = quality},
                elem_tooltip = {
                    type = "item",
                    name = item
                },
                tags = {
                    mod = "constructron",
                    on_gui_click = "clear_all_requests",
                    item_name = item,
                    surface_index = surface_index
                }
            }
            button.locked = true
            -- add flow to button
            local flow = button.add{
                type = "flow",
                style = "ctron_cargo_flow_style",
                direction = "horizontal",
                ignored_by_interaction = true
            }
            flow.style.height = 33
            flow.style.width = 33
            -- add label to flow
            local ew = flow.add{
                type = "empty-widget",
            }
            ew.style.horizontally_stretchable = true
            -- add item count label
            flow.add{
                type = "label",
                style = "ctron_cargo_item_label_style",
                caption = count
            }
        end
    end

    local request_count = #logistics_requests or 1
    -- Round up to the nearest 10
    local logistic_slot_count = math.ceil(request_count / 10) * 10
    if request_count == logistic_slot_count then
        logistic_slot_count = logistic_slot_count + 10
    end
    for i = 1, logistic_slot_count - request_count do
        logistic_table.add{
            type = "sprite-button",
            style = "slot_button",
            tags = {
                mod = "constructron",
            }
        }
    end
end

return gui_main
