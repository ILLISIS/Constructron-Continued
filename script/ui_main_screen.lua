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
    outer_main_flow.style.horizontally_stretchable = "on"

    gui_main.buildStatsSection(player, surface, main_flow)
    local outer_control_flow = outer_main_flow.add{
        type = "flow",
        direction = "horizontal"
    }
    local control_flow = outer_control_flow.add{
        type = "flow",
        direction = "horizontal"
    }
    outer_control_flow.style.horizontally_stretchable = "on"
    outer_control_flow.style.vertically_stretchable = "on"
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
    for _, iterated_surface in pairs(game.surfaces) do
        surfaces[#surfaces+1] = iterated_surface.name
    end
    global.user_interface[player.index].main_ui.elements["surface_selector"] = bar.add{
        type = "drop-down",
        name = "surface_select",
        style = "ctron_surface_dropdown_style",
        selected_index = surface.index,
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
    if global.debug_toggle then
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
        sprite = "utility/close_white",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
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
    gui_main.create_stat_card(player, surface, stats_section, {"ctron_gui_locale.stat_total_constructrons"}, "total", global.constructrons_count[surface.index])
    gui_main.create_stat_card(player, surface, stats_section, {"ctron_gui_locale.stat_available_constructrons"}, "available", global.available_ctron_count[surface.index])
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
    global.user_interface[player.index].main_ui.elements[stat] = card.add{
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
    spacer_1.style.horizontally_stretchable = "on"

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
    spacer_2.style.horizontally_stretchable = "on"
end

function gui_main.create_job_sections(player, surface, frame)
    -- create job sections
    local in_progress_section = gui_main.create_job_section(player, surface, frame, "in_progress_section", {"ctron_gui_locale.inprogress_section_name"})
    local finishing_section = gui_main.create_job_section(player, surface, frame, "finishing_section", {"ctron_gui_locale.finishing_section_name"})
    local pending_section = gui_main.create_job_section(player, surface, frame, "pending_section", {"ctron_gui_locale.pending_section_name"})
    pending_section.style.vertically_stretchable = true

    -- populate job sections with job cards
    for _, job in pairs(global.jobs) do
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
        for _, chunk in pairs(global[job_type .. '_queue'][surface.index]) do
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
        hovered_sprite = "utility/collapse_dark",
        clicked_sprite = "utility/collapse_dark",
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
    global.user_interface[player.index].main_ui.elements[section_name] = section.add{
        type = "flow",
        name = "ctron_" .. section_name .. "_inner",
        direction = "vertical"
    }
    global.user_interface[player.index].main_ui.elements[section_name].style.vertical_spacing = 0

    return global.user_interface[player.index].main_ui.elements[section_name]
end


function gui_main.create_job_card(job, section)
    local job_type = job.job_type
    local job_index = job.job_index

    -- job card
    local card = section.add{
        type = "frame",
        name = "ctron_" .. job_type .. "_card_" .. job_index,
        style = "ctron_job_card_style",
        tags = {
            mod = "constructron",
            job_index = job_index
        },
    }

    -- add job_type frame
    local label_frame = card.add{
        type = "frame",
        name = "label_frame",
        style = "ctron_job_label_frame_style",
        direction = "vertical"
    }

    -- add job_type label
    label_frame.add{
        type = "label",
        name = "ctron_job_type_label",
        caption = {"ctron_gui_locale.job_card_" .. job_type .. "_name"},
        style = "ctron_job_type_label_style"
    }

    card.add{
        type = "empty-widget",
        name = "ctron_spacer",
        style = "ctron_job_section_title_bar_style", -- TODO: this is a shared style, should this be a new one?
        ignored_by_interaction = true
    }

    -- add locate button
    card.add{
        type = "button",
        name = "ctron_locate_button",
        caption = {"ctron_gui_locale.job_locate_button"},
        tooltip = {"ctron_gui_locale.job_locate_button_tooltip"},
        style = "ctron_frame_button_style",
        tags = {
            mod = "constructron",
            on_gui_click = "ctron_locate_job",
            job_index = job_index
        }
    }

    -- add cancel button
    card.add{
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
    card.add{
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
    local card = section.add{
        type = "frame",
        style = "ctron_chunk_card_style",
        tags = {
            mod = "constructron",
            chunk_key = chunk_key,
            job_type = job_type
        }
    }

    -- add chunk_type frame
    local label_frame = card.add{
        type = "frame",
        style = "ctron_chunk_label_frame_style",
    }

    -- add chunk_type label
    label_frame.add{
        type = "label",
        caption = {"ctron_gui_locale.job_card_" .. job_type .. "_name"},
        style = "ctron_chunk_label_style"
    }

    card.add{
        type = "empty-widget",
        style = "ctron_job_section_title_bar_style",
        ignored_by_interaction = true
    }
    if not (job_type == "cargo") then
        -- add locate button
        card.add{
            type = "button",
            caption = {"ctron_gui_locale.job_locate_button"},
            style = "ctron_frame_button_style",
            tags = {
                mod = "constructron",
                on_gui_click = "ctron_locate_chunk",
                chunk_key = chunk_key,
                surface_index = surface_index,
                job_type = job_type
            }
        }

        -- add cancel button
        card.add{
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
function gui_main.BuildLogisticsDisplay(player, surface_index)
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
        caption = "All logistics requests",
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
    for _, iterated_surface in pairs(game.surfaces) do
        surfaces[#surfaces+1] = iterated_surface.name
    end
    global.user_interface[player.index].logistics_ui.elements["surface_selector"] = bar.add{
        type = "drop-down",
        name = "surface_select",
        style = "ctron_surface_dropdown_style",
        selected_index = surface_index,
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
        sprite = "utility/close_white",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
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
    global.user_interface[player.index].logistics_ui.elements["logistics_content"] = content_flow
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
    for _, job in pairs(global.jobs) do
        if (job.surface_index == surface_index) and job.state == "starting" and job.worker and job.worker.valid then
            local worker = job.worker
            for i = 1, worker.request_slot_count do
                local slot = worker.get_request_slot(i)
                if slot then
                    ctron_count = ctron_count + 1
                    if logistics_requests[slot.name] then
                        logistics_requests[slot.name] = logistics_requests[slot.name] + slot.count
                    else
                        logistics_requests[slot.name] = slot.count
                    end
                end
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



    for item, count in pairs(logistics_requests) do
        logistic_table.add{
            type = "sprite-button",
            style = "logistic_slot_button",
            elem_tooltip = {
                type = "item",
                name = item
            },
            sprite = "item/" .. item,
            number = count,
            tags = {
                mod = "constructron",
                on_gui_click = "clear_all_requests",
                item_name = item,
                surface_index = surface_index
            }
        }
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
            style = "logistic_slot_button",
            tags = {
                mod = "constructron",
            }
        }
    end
end

return gui_main