local debug_lib = require("script/debug_lib")
local util_func = require("script/utility_functions")

local gui_handlers = {}

local gui_main = require("script/ui_main_screen")
local gui_settings = require("script/ui_settings_screen")
local gui_job = require("script/ui_job_screen")
local gui_cargo = require("script/ui_cargo_screen")

--===========================================================================--
-- UI Handlers
--===========================================================================--

local gui_event_types = {
    [defines.events.on_gui_click] = "on_gui_click",
    [defines.events.on_gui_selection_state_changed] = "on_gui_selection_state_changed",
    [defines.events.on_gui_checked_state_changed] = "on_gui_checked_state_changed",
    [defines.events.on_gui_text_changed] = "on_gui_text_changed",
    [defines.events.on_gui_elem_changed] = "on_gui_elem_changed",
    [defines.events.on_gui_hover] = "on_gui_hover",
    [defines.events.on_gui_leave] = "on_gui_leave",
}

function gui_handlers.register()
    for ev, _ in pairs(gui_event_types) do
        script.on_event(ev, gui_handlers.gui_event)
    end
end

script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    storage.user_interface[player.index] = {
        surface = player.surface,
        main_ui = {
            elements = {}
        },
        settings_ui = {
            elements = {}
        },
        job_ui = {
            elements = {}
        },
        cargo_ui = {
            elements = {}
        },
        logistics_ui = {
            elements = {}
        }
    }
end)

script.on_event(defines.events.on_gui_opened, function(event)
    local entity = event.entity
    if entity and storage.constructron_names[entity.name] then
        local player = game.players[event.player_index]
        if player.gui.relative.ctron_worker_frame then return end
        local ctron_frame = player.gui.relative.add{
            type = "frame",
            name = "ctron_worker_frame",
            direction = "vertical",
            anchor = {
                gui = defines.relative_gui_type.spider_vehicle_gui,
                position = defines.relative_gui_position.right
            },
            tags = {
                mod = "constructron",
            }
        }
        ctron_frame.style.minimal_width = 100
        ctron_frame.style.maximal_width = 200

        -- find job
        local job
        for _, iterated_job in pairs(storage.jobs) do
            if iterated_job.worker and iterated_job.worker.valid and iterated_job.worker.unit_number == event.entity.unit_number then
                job = iterated_job
                break
            end
        end

        -- add remote button
        local remote_button = ctron_frame.add{
            type = "button",
            name = "ctron_remote_button",
            caption = {"ctron_gui_locale.job_remote_button"},
            style = "ctron_frame_button_style",
            tooltip = {"ctron_gui_locale.job_remote_button_tooltip"},
            tags = {
                mod = "constructron",
                on_gui_click = "ctron_remote_control",
                worker = entity.unit_number
            }
        }
        remote_button.style.horizontally_stretchable = true

        if not job then return end

        -- add locate button
        local locate_button = ctron_frame.add{
            type = "button",
            name = "ctron_locate_button",
            caption = {"ctron_gui_locale.job_locate_button"},
            tooltip = {"ctron_gui_locale.job_locate_button_tooltip"},
            style = "ctron_frame_button_style",
            tags = {
                mod = "constructron",
                on_gui_click = "ctron_locate_job",
                job_index = job.job_index
            }
        }
        locate_button.style.horizontally_stretchable = true

        -- add details button
        local details_button = ctron_frame.add{
            type = "button",
            name = "ctron_details_button",
            caption = {"ctron_gui_locale.job_details_button"},
            style = "ctron_frame_button_style",
            tooltip = {"ctron_gui_locale.job_details_button_tooltip"},
            tags = {
                mod = "constructron",
                on_gui_click = "open_job_window",
                job_index = job.job_index
            }
        }
        details_button.style.horizontally_stretchable = true

        -- add cancel button
        local cancel_button = ctron_frame.add{
            type = "button",
            name = "ctron_cancel_button",
            caption = {"ctron_gui_locale.job_cancel_button"},
            style = "ctron_frame_button_style",
            tooltip = {"ctron_gui_locale.job_cancel_button_tooltip"},
            tags = {
                mod = "constructron",
                on_gui_click = "ctron_cancel_job",
                job_index = job.job_index
            }
        }
        cancel_button.style.horizontally_stretchable = true
    elseif entity and storage.station_names[entity.name] then
        local player = game.players[event.player_index]
        if player.gui.relative.ctron_station_frame then return end
        local ctron_station_frame = player.gui.relative.add{
            type = "frame",
            name = "ctron_station_frame",
            direction = "horizontal",
            anchor = {
                gui = defines.relative_gui_type.roboport_gui,
                position = defines.relative_gui_position.top
            },
            tags = {
                mod = "constructron",
            }
        }
        local rename_flow = ctron_station_frame.add{
            type = "flow",
            direction = "horizontal"
        }
        -- add rename button
        rename_flow.add{
            type = "button",
            name = "ctron_station_rename_button",
            caption = {"ctron_gui_locale.rename_station_button"},
            style = "ctron_frame_button_style",
            tags = {
                mod = "constructron",
                on_gui_click = "rename_station",
                station_unit_number = entity.unit_number
            }
        }

        -- add cargo button
        ctron_station_frame.add{
            type = "button",
            name = "ctron_station_cargo_button",
            caption = {"ctron_gui_locale.cargo_button"},
            style = "ctron_frame_button_style",
            tooltip = {"ctron_gui_locale.cargo_button_tooltip"},
            tags = {
                mod = "constructron",
                on_gui_click = "open_cargo_window",
                station_unit_number = entity.unit_number
            }
        }
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    local player = game.players[event.player_index]
    if event.element and event.element.name == "ctron_main_window" then
        gui_handlers.close_main_window(player)
    elseif event.entity and storage.constructron_names[event.entity.name] then
        if player.gui.relative.ctron_worker_frame then
            player.gui.relative.ctron_worker_frame.destroy()
            if player.gui.screen.ctron_job_window then
                player.gui.screen.ctron_job_window.destroy()
            end
        end
        if player.gui.relative.ctron_invis_flow then
            player.gui.relative.ctron_invis_flow.destroy()
        end
    elseif event.entity and storage.station_names[event.entity.name] then
        if player.gui.relative.ctron_station_frame then
            player.gui.relative.ctron_station_frame.destroy()
            if player.gui.screen.ctron_cargo_window then
                player.gui.screen.ctron_cargo_window.destroy()
            end
        end
    end
end)

function gui_handlers.gui_event(event)
    local element = event.element
    if not element then return end
    local tags = element.tags
    if tags and tags.mod ~= "constructron" then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local event_name = gui_event_types[event.name]
    -- game.print(event_name)
    local action_name = tags[event_name]
    -- game.print(action_name)
    if not action_name then return end
    local event_handler = gui_handlers[action_name]
    if not event_handler then return end
    -- call to gui_handlers.event_name function
    event_handler(player, element, event.control)
end

function gui_handlers.update_ui_windows()
    for _, player in pairs(game.players) do
        if player.gui.screen.ctron_main_window then
            gui_handlers.update_main_gui(player)
        end
        if player.gui.screen.ctron_job_window then
            gui_handlers.update_job_gui(player)
        end
    end
end

local inprogress_job_states = {
    ["setup"] = true,
    ["starting"] = true,
    ["in_progress"] = true,
    ["robot_collection"] = true
}

function gui_handlers.update_main_gui(player)
    local main_window = player.gui.screen.ctron_main_window
    if not main_window then return end
    local main_ui_elements = storage.user_interface[player.index].main_ui.elements
    local selector = storage.user_interface[player.index].main_ui.elements["surface_selector"]
    local surface_name = selector.items[selector.selected_index]
    local surface = game.surfaces[surface_name]
    local surface_index = surface.index
    -- update stats values
    main_ui_elements.total.caption = storage.constructrons_count[surface_index]
    main_ui_elements.available.caption = storage.available_ctron_count[surface_index]
    -- update job cards
    local in_progress_section = main_ui_elements.in_progress_section
    local in_progress_section_cards = {}
    local finishing_section = main_ui_elements.finishing_section
    local finishing_section_cards = {}
    -- cache in progress section cards
    for _, card in pairs(in_progress_section.children) do
        if not card.tags["no_jobs"] then
            in_progress_section_cards[card.tags.job_index] = card
        end
    end
    -- cache finishing section cards
    for _, card in pairs(finishing_section.children) do
        if not card.tags["no_jobs"] then
            finishing_section_cards[card.tags.job_index] = card
        end
    end
    for job_index, job in pairs(storage.jobs) do
        if job.surface_index == surface_index then
            if inprogress_job_states[job.state] then
                if not in_progress_section_cards[job_index] then -- if the card doesn't exist, the job exists so create a new card to display
                    gui_main.create_job_card(job, in_progress_section)
                else
                    in_progress_section_cards[job_index].children[1].children[2].caption = job.job_status or "" -- update job status
                    in_progress_section_cards[job_index] = nil -- the job exists and the card exists, so remove it from the cache
                end
            elseif job.state == "finishing" then
                if not finishing_section_cards[job_index] then -- if the card doesn't exist, the job exists so create a new card to display
                    gui_main.create_job_card(job, finishing_section)
                else
                    finishing_section_cards[job_index].children[1].children[2].caption = job.job_status or "" -- update job status
                    finishing_section_cards[job_index] = nil -- the job exists and the card exists, so remove it from the cache
                end
            end
        end
    end
    -- destroy left over cards
    for _, card in pairs(in_progress_section_cards) do -- if the card is still in the cache, it doesn't exist in the job list so destroy it
        card.destroy()
    end
    for _, card in pairs(finishing_section_cards) do -- if the card is still in the cache, it doesn't exist in the job list so destroy it
        card.destroy()
    end
    gui_main.empty_section_check(in_progress_section)
    gui_main.empty_section_check(finishing_section)
    -- pending section
    local pending_section = main_ui_elements.pending_section
    local pending_section_cards = {
        ["construction"] = {},
        ["deconstruction"] = {},
        ["repair"] = {},
        ["upgrade"] = {},
        ["destroy"] = {},
        ["cargo"] = {}
    }
    for _, card in pairs(pending_section.children) do
        if not card.tags["no_jobs"] then
            pending_section_cards[card.tags.job_type][card.tags.chunk_key] = card
        end
    end
    for job_type, _ in pairs(pending_section_cards) do
        local queue = storage[job_type .. "_queue"][surface_index]
        for chunk_key, chunk in pairs(queue) do
            if not pending_section_cards[job_type][chunk_key] then
                gui_main.create_chunk_card(chunk, surface_index, pending_section, job_type)
            else
                pending_section_cards[job_type][chunk_key] = nil
            end
        end
        for _, card in pairs(pending_section_cards[job_type]) do
            card.destroy()
        end
    end
    gui_main.empty_section_check(pending_section)
end

function gui_handlers.update_job_gui(player)
    local job_window = player.gui.screen.ctron_job_window
    if not job_window then return end
    local job = storage.jobs[job_window.tags.job_index]
    if not job then return end
    local job_worker = job.worker
    if not job_worker then return end -- TODO: refactor this behavior
    local job_ui_elements = storage.user_interface[player.index].job_ui.elements

    -- update worker_minimap
    local worker_minimap = job_ui_elements["worker_minimap"]
    worker_minimap.position = job_worker.position
    worker_minimap.entity = job_worker

    -- update job_minimap
    job_ui_elements["job_minimap"].position = (job.task_positions[1] or job.station.position or job_worker.position)

    -- update job stats
    job_ui_elements["job_tasks_stat_label"].caption = {"ctron_gui_locale.job_job_stat_tasks_label", (#job.task_positions or "0")}

    -- update job ammo_table
    local ammo_table = job_ui_elements["ammo_table"]
    ammo_table.clear()
    gui_job.build_ammo_display(job_worker, ammo_table)

    -- update job inventory_table
    local inventory_table = job_ui_elements["inventory_table"]
    inventory_table.clear()
    gui_job.build_inventory_display(job_worker, inventory_table)

    -- update job trash_table
    local trash_table = job_ui_elements["trash_table"]
    trash_table.clear()
    gui_job.build_trash_display(job_worker, trash_table)

    -- update job logistic_table
    local logistic_table = job_ui_elements["logistic_table"]
    logistic_table.clear()
    gui_job.build_logistic_display(job_worker, logistic_table)
end

function gui_handlers.toggle_section(player, element)
    local section_name = element.tags.section_name
    if storage.user_interface[player.index].main_ui.elements[section_name].visible then
        element.sprite = "utility/expand"
    else
        element.sprite = "utility/collapse"
    end
    storage.user_interface[player.index].main_ui.elements[section_name].visible = not storage.user_interface[player.index].main_ui.elements[section_name].visible
end

function gui_handlers.open_main_window(player)
    if not player.gui.screen.ctron_main_window then
        gui_main.buildMainGui(player)
    else
        player.gui.screen.ctron_main_window.bring_to_front()
    end
end

function gui_handlers.close_main_window(player)
    for _, child in pairs(player.gui.screen.children) do
        if child.tags.mod == "constructron" then
            child.destroy()
        end
    end
end

function gui_handlers.open_settings_window(player)
    local selector = storage.user_interface[player.index].main_ui.elements["surface_selector"]
    local surface_name = selector.items[selector.selected_index]
    local surface = game.surfaces[surface_name]
    if not player.gui.screen.ctron_settings_window then
        gui_settings.buildSettingsGui(player, surface)
    else
        player.gui.screen.ctron_settings_window.bring_to_front()
    end
end

function gui_handlers.close_settings_window(player)
    if player.gui.screen.ctron_settings_window then
        player.gui.screen.ctron_settings_window.destroy()
    end
end

local job_colors = {
    ["deconstruction"] = "red",
    ["construction"] = "blue",
    ["repair"] = "purple",
    ["upgrade"] = "green",
    ["destroy"] = "black"
}

function gui_handlers.resize_gui(player)
    local main_window = player.gui.screen.ctron_main_window
    if main_window then
        main_window.style.width = 647
        main_window.location = {x = 25, y = main_window.location.y}
        main_window.ctron_main_content_frame.style.width = 623
        main_window.ctron_main_content_frame.job_scroll_pane.style.width = 623
        -- remove cargo jobs buttons from main window
        if next(main_window.children[2].children[2].children) then
            main_window.children[2].children[2].children[1].destroy()
        end
        -- remove surface select from main window
        if main_window.children[1].children[3].name == "surface_select" then
            main_window.children[1].children[3].visible = false
        end
    end
    local job_window = player.gui.screen.ctron_job_window
    if job_window then
        local resolution = player.display_resolution
        local x_coord = (resolution.width - (750 * player.display_scale))
        job_window.location = {x = x_coord, y = job_window.location.y}
    end
    if player.gui.relative.ctron_invis_flow then
        player.gui.relative.ctron_invis_flow.destroy()
    end
    local ctron_frame = player.gui.relative.add{
        type = "flow",
        name = "ctron_invis_flow",
        direction = "vertical",
        anchor = {
            gui = defines.relative_gui_type.spider_vehicle_gui,
            position = defines.relative_gui_position.right
        },
        tags = {
            mod = "constructron",
        }
    }
    ctron_frame.style.width = 5000 -- push the base game spider UI all the way to the left
end

function gui_handlers.ctron_locate_job(player, element)
    local job = storage.jobs[element.tags.job_index]
    if not job then
        player.print({"ctron_warnings.job_no_exist"}) -- TODO: refactor this functionality
        return
    end
    local _, chunk = next(job.chunks)
    chunk = chunk or {}
    local position = (chunk.midpoint or job.station.position or job.worker.position)
    player.set_controller{ type = defines.controllers.remote, position = position, surface = job.surface_index }
    -- move UI for visibility
    gui_handlers.resize_gui(player)
    -- draw chunks
    for _, chunk_to_draw in pairs(job.chunks) do
        debug_lib.draw_rectangle(chunk_to_draw.minimum, chunk_to_draw.maximum, job.surface_index, job_colors[job.job_type], true, 120)
    end
end

function gui_handlers.ctron_locate_chunk(player, element)
    local job_type = element.tags.job_type
    local surface_index = element.tags.surface_index
    local chunk = storage[job_type .. '_queue'][surface_index][element.tags.chunk_key]
    if not chunk then return end
    local chunk_midpoint = {x = ((chunk.minimum.x + chunk.maximum.x) / 2), y = ((chunk.minimum.y + chunk.maximum.y) / 2)}
    player.set_controller{ type = defines.controllers.remote, position = chunk_midpoint, surface = surface_index }
    -- move UI for visibility
    gui_handlers.resize_gui(player)
    -- draw chunk
    debug_lib.draw_rectangle(chunk.minimum, chunk.maximum, surface_index, job_colors[job_type], true, 120)
end

function gui_handlers.ctron_map_view(player, element)
    local job = storage.jobs[element.tags.job_index]
    if not job then return end
    if element.tags.follow_entity then
        player.set_controller{ type = defines.controllers.remote, surface = job.worker.surface}
        player.centered_on = job.worker
    else
        local current_task = 1
        if #job.task_positions > 1 then
            current_task = math.random(1, #job.task_positions)
        end
        local position = (job.task_positions[current_task] or job.station.position or job.worker.position)
        player.set_controller{ type = defines.controllers.remote, position = position, surface = job.worker.surface }
        -- draw chunks
        for _, chunk_to_draw in pairs(job.chunks) do
            debug_lib.draw_rectangle(chunk_to_draw.minimum, chunk_to_draw.maximum, job.surface_index, job_colors[job.job_type], true, 120)
        end
    end
    -- move UI for visibility
    gui_handlers.resize_gui(player)
end

function gui_handlers.ctron_cancel_job(player, element, ctrl_clicked)
    local selected_job = storage.jobs[element.tags.job_index]
    if not selected_job then
        player.print({"ctron_warnings.job_no_exist"}) -- TODO: refactor this functionality
        return
    end

    local job_list = {}
    if ctrl_clicked then
        for _, iterated_job in pairs(storage.jobs) do
            local type_check = (iterated_job.job_type == selected_job.job_type)
            local surface_check = (iterated_job.surface_index == selected_job.surface_index)
            local state_check = (iterated_job.state ~= "finishing")
            if type_check and surface_check and state_check then
                table.insert(job_list, iterated_job)
            end
        end
    else
        job_list = { [1] = selected_job }
    end

    -- Make sure GUI elements exist before starting the loop
    local ui = storage.user_interface[player.index]
    local main_window = player.gui.screen.ctron_main_window
    local main_ui = ui and ui.main_ui
    local in_progress = main_ui and main_ui.elements["in_progress_section"]
    local finishing = main_ui and main_ui.elements["finishing_section"]

    for _, job in pairs(job_list) do
        if job.state ~= "finishing" then
            -- handle job cancellation
            job.state = "finishing"
            if job.worker then
                job.worker.autopilot_destination = nil
            end
            if job.job_type == "cargo" then
                local station_unit_number = job.destination_station.unit_number
                for _, request in pairs(storage.station_requests[station_unit_number]) do
                    local requested_item = request.name
                    for item, value in pairs(job.required_items) do
                        for quality, item_count in pairs(value) do
                            if requested_item == item and request.quality == quality then
                                request.in_transit_count = request.in_transit_count - item_count
                                break
                            end
                        end
                    end
                end
            end
            for _, chunk in pairs(job.chunks) do
                chunk.skip_chunk_checks = true
            end
            -- Update UI
            if main_window and element and element.valid and not element.tags.job_screen and in_progress and finishing then
                gui_main.create_job_card(job, finishing)
                local job_card = in_progress["ctron_" .. job.job_type .. "_card_" .. job.job_index]
                if job_card then
                    job_card.destroy()
                end
                gui_main.empty_section_check(in_progress)
            end
        else
            player.print({"ctron_warnings.job_finished"}) -- TODO: refactor this functionality
        end
    end
end

function gui_handlers.open_job_window(player, element)
    local job = storage.jobs[element.tags.job_index]
    if not job then
        player.print({"ctron_warnings.job_no_exist"}) -- TODO: refactor this functionality
        return
    end
    if not player.gui.screen.ctron_job_window then
        gui_job.buildJobGui(player, job)
    else
        player.gui.screen.ctron_job_window.destroy()
        gui_job.buildJobGui(player, job)
    end
end

function gui_handlers.close_job_window(player)
    if player.gui.screen.ctron_job_window then
        player.gui.screen.ctron_job_window.destroy()
    end
end

function gui_handlers.ctron_cancel_chunk(player, element, ctrl_clicked)
    local job_type = element.tags.job_type
    local surface_index = element.tags.surface_index
    if ctrl_clicked then
        storage[job_type .. '_queue'][surface_index] = {}
        for _, child in pairs(storage.user_interface[player.index].main_ui.elements["pending_section"].children) do
            child.destroy()
        end
    else
        storage[job_type .. '_queue'][surface_index][element.tags.chunk_key] = nil
        element.parent.parent.destroy()
    end
    gui_main.empty_section_check(storage.user_interface[player.index].main_ui.elements["pending_section"])
end

function gui_handlers.selected_new_surface(player, element)
    local new_surface = game.surfaces[element.items[element.selected_index]]
    if not new_surface then return end
    if element.tags["surface_selector"] == "ctron_main" then
        storage.user_interface[player.index]["surface"] = new_surface
        gui_handlers.update_main_gui(player)
    elseif element.tags["surface_selector"] == "ctron_settings" then
        gui_handlers.update_settings_gui(player, new_surface)
    elseif element.tags["surface_selector"] == "cargo_selector" then
        local cargo_content = storage.user_interface[player.index]["cargo_ui"]["elements"].cargo_content
        for _, child in pairs(cargo_content.children) do
            child.destroy()
        end
        gui_cargo.buildCargoContent(player, new_surface, cargo_content)
    elseif element.tags["surface_selector"] == "logistics_selector" then
        local logistics_content = storage.user_interface[player.index]["logistics_ui"]["elements"].logistics_content
        for _, child in pairs(logistics_content.children) do
            child.destroy()
        end
        gui_main.BuildLogisticsContent(player, new_surface, logistics_content)
    end
end

function gui_handlers.update_settings_gui(player, surface)
    local content_section = player.gui.screen.ctron_settings_window.ctron_settings_inner_frame.ctron_settings_scroll
    if not content_section then return end
    content_section.clear()
    gui_settings.buildSettingsContent(player, surface, content_section)
end

function gui_handlers.toggle_job_setting(player, element)
    local setting = element.tags.setting
    local setting_surface = element.tags.setting_surface
    storage[setting .. "_job_toggle"][setting_surface] = not storage[setting .. "_job_toggle"][setting_surface]
    -- update job state to prematurely finish jobs in progress
    for _, job in pairs(storage.jobs) do
        if (job.surface_index == setting_surface) and (job.job_type == setting) then
            job.worker.autopilot_destination = nil
            job.state = "finishing"
        end
    end
    -- remove pending chunks
    storage[setting .. "_queue"][setting_surface] = {}
end

function gui_handlers.change_robot_count(player, element)
    local setting_surface = element.tags.setting_surface
    local count = (tonumber(element.text) or 50)
    if count > 10000 then
        player.print("Specified robot count too high, count reset to 50.")
        count = 50
    end
    storage.desired_robot_count[setting_surface] = count
end

function gui_handlers.select_new_robot(player, element)
    local setting_surface = element.tags.setting_surface
    storage.desired_robot_name[setting_surface] = element.elem_value
end

function gui_handlers.selected_new_ammo(player, element)
    local setting_surface = element.tags.setting_surface
    -- validate selection -- TODO: check if choose-elem-button can be filtered further in future API versions.
    if not element.elem_value then
        element.elem_value = storage.ammo_name[setting_surface]
    end
    if not (prototypes.item[element.elem_value.name].ammo_category.name == "rocket") then
        element.elem_value = storage.ammo_name[setting_surface]
        player.print({"ctron_warnings.invalid_ammo"})
        return
    end
    -- update existing jobs with new ammo selection
    for _, job in pairs(storage.jobs) do
        if (job.surface_index == setting_surface) then
            if job.required_items[storage.ammo_name[setting_surface].name] then
                -- remove old ammo from job
                job.required_items[storage.ammo_name[setting_surface].name] = nil
                -- add new ammo to job
                job.required_items[element.elem_value.name] = {
                    [element.elem_value.quality] = storage.ammo_count[setting_surface]
                }
            end
        end
    end
    -- change setting
    storage.ammo_name[setting_surface] = element.elem_value
end

function gui_handlers.change_ammo_count(player, element)
    local setting_surface = element.tags.setting_surface
    local count = (tonumber(element.text) or 50)
    if count > 10000 then
        player.print("Specified ammo count too high, count reset to 0.")
        count = 0
    end
    storage.ammo_count[setting_surface] = count
end

function gui_handlers.selected_new_repair_tool(player, element)
    local setting_surface = element.tags.setting_surface
    storage.repair_tool_name[setting_surface] = element.elem_value
end

function gui_handlers.toggle_debug_mode(player, element)
    storage.debug_toggle = not storage.debug_toggle
    if storage.debug_toggle then
        element.caption = {"ctron_gui_locale.debug_button_on"}
    else
        element.caption = {"ctron_gui_locale.debug_button_off"}
    end
end

function gui_handlers.toggle_horde_mode(player, element)
    local setting_surface = element.tags.setting_surface
    storage.horde_mode[setting_surface] = not storage.horde_mode[setting_surface]
end

function gui_handlers.change_job_start_delay(player, element)
    storage.job_start_delay = ((tonumber(element.text) or 0) * 60)
end

function gui_handlers.clear_logistic_request(player, element)
    local worker = storage.constructrons[element.tags.unit_number]
    if not worker then return end
    local logistic_point = worker.get_logistic_point(0) ---@cast logistic_point -nil
    local section = logistic_point.get_section(1)
    local item_name = element.elem_value.name
    local quality = element.elem_value.quality
    for slot, request in pairs(section.filters) do
        if request and request.value and (request.value.name == item_name) and (request.value.quality == quality) then
            section.clear_slot(slot)
        end
    end
    element.elem_value = nil
    element.elem_tooltip = nil
    element.children[1].destroy()
    element.tags = {
        mod = "constructron",
    }
end

function gui_handlers.ctron_remote_control(player, element)
    player.spidertron_remote_selection = {storage.constructrons[element.tags.worker]}
    local cursor_stack = player.cursor_stack
    if not cursor_stack then return end
    if not player.clear_cursor() then return end
    local remote = {name = "spidertron-remote", count = 1}
    if not cursor_stack.can_set_stack(remote) then return end
    cursor_stack.set_stack(remote)
end

function gui_handlers.apply_settings_template(player, element)
    local current_surface = element.tags.setting_surface
    for _, surface in pairs(game.surfaces) do
        local surface_index = surface.index
        storage.horde_mode[surface_index] = storage.horde_mode[current_surface]
        storage.construction_job_toggle[surface_index] = storage.construction_job_toggle[current_surface]
        storage.rebuild_job_toggle[surface_index] = storage.rebuild_job_toggle[current_surface]
        storage.deconstruction_job_toggle[surface_index] = storage.deconstruction_job_toggle[current_surface]
        storage.upgrade_job_toggle[surface_index] = storage.upgrade_job_toggle[current_surface]
        storage.repair_job_toggle[surface_index] = storage.repair_job_toggle[current_surface]
        storage.destroy_job_toggle[surface_index] = storage.destroy_job_toggle[current_surface]
        storage.zone_restriction_job_toggle[surface_index] = storage.zone_restriction_job_toggle[current_surface]
        storage.ammo_name[surface_index] = storage.ammo_name[current_surface]
        storage.ammo_count[surface_index] = storage.ammo_count[current_surface]
        storage.desired_robot_count[surface_index] = storage.desired_robot_count[current_surface]
        storage.desired_robot_name[surface_index] = storage.desired_robot_name[current_surface]
        storage.repair_tool_name[surface_index] = storage.repair_tool_name[current_surface]
    end
end

function gui_handlers.clear_all_requests(player, element)
    local surface = game.surfaces[element.tags.surface_index]
    local item_name = element.elem_value.name
    local quality = element.elem_value.quality

    for _, job in pairs(storage.jobs) do
        if (job.surface_index == surface.index) and job.state == "starting" and job.worker and job.worker.valid then
            local worker = job.worker
            local logistic_point = worker.get_logistic_point(0) ---@cast logistic_point -nil
            local section = logistic_point.get_section(1)
            for slot, request in pairs(section.filters) do
                if request and request.value and (request.value.name == item_name) and (request.value.quality == quality) then
                    section.clear_slot(slot)
                end
            end
        end
    end
    element.elem_value = nil
    element.children[1].destroy()
end

function gui_handlers.rename_station(player, element)
    local station = storage.service_stations[element.tags.station_unit_number]
    if not station then return end
    -- create text field
    element.parent.add{
        type = "textfield",
        text = station.backer_name,
        tags = {
            mod = "constructron",
        }
    }
    -- create confirm button
    element.parent.add{
        type = "button",
        caption = {"ctron_gui_locale.confirm_rename_button"},
        style = "ctron_frame_button_style",
        tags = {
            mod = "constructron",
            on_gui_click = "confirm_rename",
            station_unit_number = element.tags.station_unit_number
        }
    }
    -- delete the button
    element.destroy()
end

function gui_handlers.confirm_rename(player, element)
    local station = storage.service_stations[element.tags.station_unit_number]
    if not station then return end
    station.backer_name = element.parent.children[1].text or ""
    local parent = element.parent
    -- create the rename button
    parent.add{
        type = "button",
        caption = {"ctron_gui_locale.rename_station_button"},
        style = "ctron_frame_button_style",
        tags = {
            mod = "constructron",
            on_gui_click = "rename_station",
            station_unit_number = element.tags.station_unit_number
        }
    }
    -- delete the text field
    element.parent.children[1].destroy()
    -- delete the confirm button
    element.destroy()
end

function gui_handlers.open_cargo_window(player, element)
    if not player.gui.screen.ctron_cargo_window then
        if not element.tags.station_unit_number then 
            local selector = storage.user_interface[player.index].main_ui.elements["surface_selector"]
            local surface_name = selector.items[selector.selected_index]
            local surface = game.surfaces[surface_name]
            gui_cargo.buildCargoGui(player, surface)
            return
        end
        local station = storage.service_stations[element.tags.station_unit_number]
        gui_cargo.buildCargoGui(player, game.surfaces[station.surface.name])
        gui_handlers.cargo_hide_stations(player, element)
    else
        player.gui.screen.ctron_cargo_window.bring_to_front()
    end
end

function gui_handlers.close_cargo_window(player)
    if player.gui.screen.ctron_cargo_window then
        player.gui.screen.ctron_cargo_window.destroy()
    end
end

function gui_handlers.cargo_hide_stations(player, element)
    if (storage.stations_count[player.surface.index] > 1) then
        local cargo_content = storage.user_interface[player.index]["cargo_ui"]["elements"].cargo_content
        -- hide station cards
        for _, child in pairs(cargo_content.children) do
            if not (child.tags.station_unit_number == element.tags.station_unit_number) then
                child.visible = false
            end
        end
        local flow = cargo_content.add{
            type = "flow",
            direction = "horizontal"
        }
        flow.style.horizontally_stretchable = true
        flow.style.height = 50
        flow.style.horizontal_align = "center"
        flow.style.vertical_align = "center"
        local button = flow.add{
            type = "button",
            caption = {"ctron_gui_locale.show_all_stations_button"},
            style = "ctron_frame_button_style",
            tags = {
                mod = "constructron",
                on_gui_click = "cargo_show_all_stations",
            }
        }
    end
end

function gui_handlers.cargo_show_all_stations(player, element)
    local cargo_content = storage.user_interface[player.index]["cargo_ui"]["elements"].cargo_content
    for _, child in pairs(cargo_content.children) do
        child.visible = true
    end
    element.parent.destroy()
end

function gui_handlers.open_logistics_window(player, element)
    local selector = storage.user_interface[player.index].main_ui.elements["surface_selector"]
    local surface_name = selector.items[selector.selected_index]
    local surface = game.surfaces[surface_name]
    if not player.gui.screen.ctron_logistics_window then
        gui_main.BuildLogisticsDisplay(player, surface)
    else
        player.gui.screen.ctron_logistics_window.destroy()
        gui_main.BuildLogisticsDisplay(player, surface)
    end
end

function gui_handlers.close_logistics_window(player)
    if player.gui.screen.ctron_logistics_window then
        player.gui.screen.ctron_logistics_window.destroy()
    end
end

function gui_handlers.on_gui_elem_changed(player, element)
    if element.elem_value ~= nil then
        local slot_number = element.tags.slot_number
        local item = element.elem_value.name
        local quality = element.elem_value.quality
        local station_unit_number = element.tags.station_unit_number
        if not storage.station_requests[station_unit_number] then
            player.print({"ctron_warnings.station_no_exist"})
            gui_handlers.close_cargo_window(player)
            gui_handlers.open_cargo_window(player)
            return
        end
        local request = storage.station_requests[station_unit_number][slot_number]
        -- check if item is already requested
        for k, v in pairs(element.parent.children) do
            if v.elem_value and v.elem_value == item and v.name ~= element.name then
                element.elem_value = nil
                element.style = "ctron_slot_button"
                player.print({"ctron_warnings.item_already_requested"})
                return
            end
        end
        -- activate ui
        element.style = "ctron_slot_button_selected"
        local cargo_ui_elements = storage.user_interface[player.index]["cargo_ui"]["elements"]
        cargo_ui_elements.min_field.enabled = true
        cargo_ui_elements.max_field.enabled = true
        if request and (request.name == item) then
            cargo_ui_elements.min_field.text = tostring(storage.station_requests[station_unit_number][slot_number].min)
            cargo_ui_elements.max_field.text = tostring(storage.station_requests[station_unit_number][slot_number].max)
        end
        local confirm_button = storage.user_interface[player.index].cargo_ui.elements.confirm_button
        local tags = confirm_button.tags
        tags.station_unit_number = station_unit_number
        tags.item_request = item
        tags.item_quality = quality
        tags.slot_number = slot_number
        confirm_button.tags = tags
        confirm_button.enabled = true
    else
        storage.station_requests[element.tags.station_unit_number][element.tags.slot_number] = nil
        if next(element.children) then
            element.children[1].destroy()
        end
        element.style = "ctron_slot_button"
        gui_handlers.reset_controls(player)
    end
end

function gui_handlers.confirm_cargo(player, element)
    local station_unit_number = element.tags.station_unit_number
    local station = storage.service_stations[station_unit_number]
    if not station then return end
    local slot_number = element.tags.slot_number
    local item = element.tags.item_request
    local quality = element.tags.item_quality
    local cargo_ui_elements = storage.user_interface[player.index]["cargo_ui"]["elements"]
    if item then
        local min = tonumber(cargo_ui_elements.min_field.text) or 0
        local max = tonumber(cargo_ui_elements.max_field.text) or 0
        -- validate input
        if min >= max then
            player.print({"ctron_warnings.min_value"})
            return
        end
        if max <= min then
            player.print({"ctron_warnings.max_value"})
            return
        end
        storage.station_requests[station_unit_number][slot_number] = {
            name = item,
            quality = quality,
            min = min or 0,
            max = max or 0,
            in_transit_count = 0
        }

        local button = cargo_ui_elements[station_unit_number]["ctron_request_slot_" .. slot_number]
        button.style = "ctron_slot_button"
        if next(button.children) then
            button.children[1].destroy()
        end

        -- add flow to button
        local flow = button.add{
            type = "flow",
            style = "ctron_cargo_flow_style",
            direction = "horizontal"
        }
        flow.ignored_by_interaction = true
        -- add label to flow
        flow.add{
            type = "empty-widget",
            style = "ctron_cargo_widget_style",
        }
        -- add item count label
        flow.add{
            type = "label",
            name = "ctron_cargo_content_label",
            style = "ctron_cargo_item_label_style",
            caption = util_func.number(max, true)
        }
    end
    gui_handlers.reset_controls(player)
end

-- function to reset min/max and button
function gui_handlers.reset_controls(player)
    local cargo_ui_elements = storage.user_interface[player.index]["cargo_ui"]["elements"]
    cargo_ui_elements.min_field.text = "0"
    cargo_ui_elements.max_field.text = "0"
    cargo_ui_elements.min_field.enabled = false
    cargo_ui_elements.max_field.enabled = false
    cargo_ui_elements.confirm_button.enabled = false
end

function gui_handlers.copy_station_requests(player, element)
    storage.user_interface[player.index]["settings_export"] = table.deepcopy(storage.station_requests[element.tags.station_unit_number])
end

function gui_handlers.paste_station_requests(player, element)
    storage.station_requests[element.tags.station_unit_number] = table.deepcopy(storage.user_interface[player.index]["settings_export"])
    player.gui.screen.ctron_cargo_window.destroy()
    gui_cargo.buildCargoGui(player, player.surface)
end

function gui_handlers.on_gui_hover_job(player, element)
    local job = storage.jobs[element.tags.job_index]
    if not job then return end
    local _, chunk = next(job.chunks)
    chunk = chunk or {}
    local destination_station = job.destination_station or {}
    local position = (chunk.midpoint or destination_station.position or job.task_positions[1] or job.worker.position)
    if not position then return end
    if player.gui.screen.ctron_hover_frame then
        player.gui.screen.ctron_hover_frame.destroy()
    end
    local frame = player.gui.screen.add{
        type = "frame",
        name = "ctron_hover_frame",
        tags = {
            mod = "constructron",
        }
    }
    frame.auto_center = true
    local inner_frame = frame.add{
        type = "frame",
        direction = "vertical",
        style = "inside_deep_frame"
    }
    local cam = inner_frame.add{
        type = "camera",
        position = position,
        zoom = 0.30
    }
    cam.style.height = 500
    cam.style.width = 500
end

function gui_handlers.on_gui_hover_chunk(player, element)
    local job_type = element.tags.job_type
    local surface_index = element.tags.surface_index
    local chunk = storage[job_type .. '_queue'][surface_index][element.tags.chunk_key]
    if not chunk then return end
    local chunk_midpoint = {x = ((chunk.minimum.x + chunk.maximum.x) / 2), y = ((chunk.minimum.y + chunk.maximum.y) / 2)}
    if player.gui.screen.ctron_hover_frame then
        player.gui.screen.ctron_hover_frame.destroy()
    end
    local frame = player.gui.screen.add{
        type = "frame",
        name = "ctron_hover_frame",
        tags = {
            mod = "constructron",
        }
    }
    frame.auto_center = true
    local inner_frame = frame.add{
        type = "frame",
        direction = "vertical",
        style = "inside_deep_frame"
    }
    local cam = inner_frame.add{
        type = "camera",
        position = chunk_midpoint,
        zoom = 0.30
    }
    cam.style.height = 500
    cam.style.width = 500
end



function gui_handlers.on_gui_leave(player, element)
    if player.gui.screen.ctron_hover_frame then
        player.gui.screen.ctron_hover_frame.destroy()
    end
end

return gui_handlers
