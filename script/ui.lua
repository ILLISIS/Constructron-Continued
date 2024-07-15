local debug_lib = require("script/debug_lib")

local gui_handlers = {}
local gui_builder = {}

local gui_main = require("script/ui_main_screen")
local gui_settings = require("script/ui_settings_screen")
local gui_job = require("script/ui_job_screen")

-- TODO: handle surface add/remove/rename
-- TODO: anchored UI relative ctron -> job

--===========================================================================--
-- UI Handlers
--===========================================================================--

local gui_event_types = {
    [defines.events.on_gui_click] = "on_gui_click",
    [defines.events.on_gui_closed] = "on_gui_closed",
    [defines.events.on_gui_selection_state_changed] = "on_gui_selection_state_changed",
    [defines.events.on_gui_checked_state_changed] = "on_gui_checked_state_changed",
    [defines.events.on_gui_text_changed] = "on_gui_text_changed"
}

function gui_handlers.register()
    for ev, _ in pairs(gui_event_types) do
        script.on_event(ev, gui_handlers.gui_event)
    end
end

-- TODO: existing players

script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    global.user_interface[player.index] = {
        surface = player.surface,
        main_ui = {
            elements = {}
        },
        settings_ui = {
            elements = {}
        },
        job_ui = {
            elements = {}
        }
    }
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
    -- call to handlers[event_name] function
    event_handler(player, global.user_interface[player.index]["surface"], element)
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
    ["new"] = true,
    ["starting"] = true,
    ["in_progress"] = true,
    ["robot_collection"] = true
}

function gui_handlers.update_main_gui(player)
    local main_window = player.gui.screen.ctron_main_window
    if main_window then
        local main_ui_elements = global.user_interface[player.index].main_ui.elements
        local surface_index = game.surfaces[main_ui_elements["surface_selector"].selected_index].index -- TODO: test in multiplayer
        -- update stats values
        main_ui_elements.total.caption = global.constructrons_count[surface_index]
        main_ui_elements.available.caption = global.available_ctron_count[surface_index]
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
        for job_index, job in pairs(global.jobs) do
            if job.surface_index == surface_index then
                if inprogress_job_states[job.state] then
                    if not in_progress_section_cards[job_index] then -- if the card doesn't exist, the job exists so create a new card to display
                        gui_main.create_job_card(job, in_progress_section)
                    else
                        in_progress_section_cards[job_index] = nil -- the job exists and the card exists, so remove it from the cache
                    end
                elseif job.state == "finishing" then
                    if not finishing_section_cards[job_index] then -- if the card doesn't exist, the job exists so create a new card to display
                        gui_main.create_job_card(job, finishing_section)
                    else
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
            ["destroy"] = {}
        }
        for _, card in pairs(pending_section.children) do
            if not card.tags["no_jobs"] then
                pending_section_cards[card.tags.job_type][card.tags.chunk_key] = card
            end
        end
        for job_type, _ in pairs(pending_section_cards) do
            local queue = global[job_type .. "_queue"][surface_index]
            for chunk_key, chunk in pairs(queue) do
                if not pending_section_cards[job_type][chunk_key] then
                    gui_main.create_chunk_card(chunk, pending_section, job_type, chunk_key) -- note: count is substituted for chunk_key
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
end

-- update settings
function gui_handlers.update_settings_gui(player, surface)
    local content_section = player.gui.screen.ctron_settings_window.ctron_settings_inner_frame.ctron_settings_scroll
    if not content_section then return end
    content_section.clear()
    gui_settings.buildSettingsContent(player, surface, content_section)
end

function gui_handlers.update_job_gui(player)
    local job_window = player.gui.screen.ctron_job_window
    if not job_window then return end
    local job = global.jobs[job_window.tags.job_index]
    if not job then return end
    local job_worker = job.worker
    if not job_worker then return end -- TODO: refactor this behavior
    local job_ui_elements = global.user_interface[player.index].job_ui.elements

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

-- update job logistic requests
-- function gui_handlers.update_job_logistic_requests(player, job)
--     local job_window = player.gui.screen.ctron_job_window
--     if not job_window then return end
--     local content_section = job_window.ctron_job_inner_frame
--     if not content_section then return end
--     content_section.clear()
--     gui_builder.buildJobContent(player, job_window, content_section, job)
-- end

function gui_handlers.toggle_section(player, surface, element)
    section_name = element.tags.section_name
    if global.user_interface[player.index].main_ui.elements[section_name].visible then
        element.sprite = "utility/expand"
        element.hovered_sprite = "utility/expand_dark"
        element.clicked_sprite = "utility/expand_dark"
    else
        element.sprite = "utility/collapse"
        element.hovered_sprite = "utility/collapse_dark"
        element.clicked_sprite = "utility/collapse_dark"
    end
    global.user_interface[player.index].main_ui.elements[section_name].visible = not global.user_interface[player.index].main_ui.elements[section_name].visible
end

function gui_handlers.open_main_window(player)
    if not player.gui.screen.ctron_main_window then
        global.user_interface[player.index] = {
            surface = player.surface,
            main_ui = {
                elements = {}
            },
            settings_ui = {
                elements = {}
            },
            job_ui = {
                elements = {}
            }
        } -- TODO: refactor this
        gui_main.buildMainGui(player, player.surface)
    else
        player.gui.screen.ctron_main_window.bring_to_front()
    end
    player.cursor_stack.clear()
end

function gui_handlers.close_main_window(player)
    for _, child in pairs(player.gui.screen.children) do
        if child.tags.mod == "constructron" then
            child.destroy()
        end
    end
end

function gui_handlers.open_settings_window(player)
    if not player.gui.screen.ctron_settings_window then
        gui_settings.buildSettingsGui(player, player.surface)
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

function gui_handlers.ctron_locate_job(player, surface, element)
    local job = global.jobs[element.tags.job_index]
    if not job then return end
    local surface_name = surface.name
    local _, chunk = next(job.chunks)

    -- Thanks Xorimuth
    if remote.interfaces["space-exploration"] and remote.interfaces["space-exploration"]["remote_view_is_unlocked"] and
        remote.call("space-exploration", "remote_view_is_unlocked", { player = player }) then
        surface_name = surface_name:gsub("^%l", string.upper)
        remote.call("space-exploration", "remote_view_start", {player = player, zone_name = surface_name, position = chunk.midpoint})
        if remote.call("space-exploration", "remote_view_is_active", { player = player }) then
            -- remote_view_start worked
            remote_view_used = true
            player.close_map()
            player.zoom = 0.5
        end
    end
    if not remote_view_used then
        player.zoom_to_world(chunk.midpoint, 0.5)
    end
    -- draw chunk
    for _, chunk_to_draw in pairs(job.chunks) do
        debug_lib.draw_rectangle(chunk_to_draw.minimum, chunk_to_draw.maximum, surface, job_colors[job.job_type], true, 300)
    end
end

function gui_handlers.ctron_locate_chunk(player, surface, element)
    local job_type = element.tags.job_type
    local chunk = global[job_type .. '_queue'][surface.index][element.tags.chunk_key]
    if not chunk then return end
    local surface_name = surface.name
    chunk_midpoint = {x = ((chunk.minimum.x + chunk.maximum.x) / 2), y = ((chunk.minimum.y + chunk.maximum.y) / 2)}

    -- Thanks Xorimuth
    if remote.interfaces["space-exploration"] and remote.interfaces["space-exploration"]["remote_view_is_unlocked"] and
        remote.call("space-exploration", "remote_view_is_unlocked", { player = player }) then
        surface_name = surface_name:gsub("^%l", string.upper)
        remote.call("space-exploration", "remote_view_start", {player = player, zone_name = surface_name, position = chunk_midpoint})
        if remote.call("space-exploration", "remote_view_is_active", { player = player }) then
            -- remote_view_start worked
            remote_view_used = true
            player.close_map()
            player.zoom = 0.5
        end
    end
    if not remote_view_used then
        player.zoom_to_world(chunk_midpoint, 0.5)
    end
    -- draw chunk
    debug_lib.draw_rectangle(chunk.minimum, chunk.maximum, surface, job_colors[job_type], true, 300)
end

function gui_handlers.ctron_map_view(player, surface, element)
    local job = global.jobs[element.tags.job_index]
    if not job then return end
    if element.tags.follow_entity then
        player.zoom_to_world(job.worker.position, 0.5, job.worker)
    else
        player.zoom_to_world(job.task_positions[math.random(1, #job.task_positions)], 0.5)
    end
end

function gui_handlers.ctron_cancel_job(player, surface, element)
    local job = global.jobs[element.tags.job_index]
    if not job then
        player.print("This job no longer exists.") -- TODO: refactor this functionality
        return
    end
    if job.state ~= "finishing" then
        -- handle job cancellation
        job.state = "finishing"
        if job.worker then
            job.worker.autopilot_destination = nil
        end
        -- set skip chunk checks
        for _, chunk in pairs(job.chunks) do
            chunk.skip_chunk_checks = true
        end
        -- update gui
        gui_main.create_job_card(job, global.user_interface[player.index].main_ui.elements["finishing_section"])
        element.parent.destroy()
        gui_main.empty_section_check(global.user_interface[player.index].main_ui.elements["in_progress_section"])
    else
        player.print("Job is already finishing.") -- TODO: refactor this functionality
    end
end

function gui_handlers.open_job_window(player, surface, element)
    local job = global.jobs[element.tags.job_index]
    if not job or not player.gui.screen.ctron_job_window then
        gui_job.buildJobGui(player, surface, job)
    else
        player.gui.screen.ctron_job_window.destroy()
        gui_job.buildJobGui(player, surface, job)
    end
end

function gui_handlers.close_job_window(player)
    if player.gui.screen.ctron_job_window then
        player.gui.screen.ctron_job_window.destroy()
    end
end

function gui_handlers.ctron_cancel_chunk(player, surface, element)
    local job_type = element.tags.job_type
    global[job_type .. '_queue'][surface.index][element.tags.chunk_key] = nil
    element.parent.destroy()
end

function gui_handlers.selected_new_surface(player, surface, element)
    local new_surface = game.surfaces[element.selected_index]
    if not new_surface then return end
    if element.tags["surface_selector"] == "ctron_main" then
        global.user_interface[player.index]["surface"] = game.surfaces[element.selected_index]
        gui_handlers.update_main_gui(player)
    elseif element.tags["surface_selector"] == "ctron_settings" then
        gui_handlers.update_settings_gui(player, new_surface)
    end
end

function gui_handlers.toggle_job_setting(player, surface, element)
    local setting = element.tags.setting
    local setting_surface = element.tags.setting_surface
    global[setting .. "_job_toggle"][setting_surface] = not global[setting .. "_job_toggle"][setting_surface]
end

function gui_handlers.change_robot_count(player, surface, element)
    local setting_surface = element.tags.setting_surface
    global.desired_robot_count[setting_surface] = (tonumber(element.text) or 50)
end

function gui_handlers.select_new_robot(player, surface, element)
    local setting_surface = element.tags.setting_surface
    global.desired_robot_name[setting_surface] = element.items[element.selected_index]
end

function gui_handlers.selected_new_ammo(player, surface, element)
    local setting_surface = element.tags.setting_surface
    global.ammo_name[setting_surface] = element.items[element.selected_index]
end

function gui_handlers.change_ammo_count(player, surface, element)
    local setting_surface = element.tags.setting_surface
    global.ammo_count[setting_surface] = (tonumber(element.text) or 0)
end

function gui_handlers.selected_new_repair_tool(player, surface, element)
    local setting_surface = element.tags.setting_surface
    global.repair_tool_name[setting_surface] = element.items[element.selected_index]
end

function gui_handlers.toggle_debug_mode(player, surface, element)
    global.debug_toggle = not global.debug_toggle
    if global.debug_toggle then
        element.caption = {"ctron_gui_locale.debug_button_on"}
    else
        element.caption = {"ctron_gui_locale.debug_button_off"}
    end
end

function gui_handlers.toggle_horde_mode(player, surface, element)
    global.horde_mode = not global.horde_mode
end

function gui_handlers.change_job_start_delay(player, surface, element)
    global.job_start_delay = ((tonumber(element.text) or 0) * 60)
end

function gui_handlers.change_entities_per_second(player, surface, element)
    global.entities_per_second = (tonumber(element.text) or 1000)
end

function gui_handlers.clear_logistic_request(player, surface, element)
    local logistic_slot = element.tags.logistic_slot
    local worker = global.constructrons[element.tags.unit_number]
    worker.clear_vehicle_logistic_slot(logistic_slot)
    element.sprite = nil
    element.tooltip = nil
    element.number = nil
    element.tags = {
        mod = "constructron",
    }
end

function gui_handlers.ctron_remote_control(player, surface, element)
    local cursor_stack = player.cursor_stack
    if not cursor_stack then return end
    if not player.clear_cursor() then return end
    local remote = {name = "spidertron-remote", count = 1}
    if not cursor_stack.can_set_stack(remote) then return end
    local worker = global.constructrons[element.tags.worker]
    if not worker then return end
    cursor_stack.set_stack(remote)
    cursor_stack.connected_entity = worker
end

function gui_handlers.apply_settings_template(player, _, element)
    local current_surface = element.tags.setting_surface
    for _, surface in pairs(game.surfaces) do
        local surface_index = surface.index
        global.construction_job_toggle[surface_index] = global.construction_job_toggle[current_surface]
        global.rebuild_job_toggle[surface_index] = global.rebuild_job_toggle[current_surface]
        global.deconstruction_job_toggle[surface_index] = global.deconstruction_job_toggle[current_surface]
        global.upgrade_job_toggle[surface_index] = global.upgrade_job_toggle[current_surface]
        global.repair_job_toggle[surface_index] = global.repair_job_toggle[current_surface]
        global.destroy_job_toggle[surface_index] = global.destroy_job_toggle[current_surface]
        global.ammo_name[surface_index] = global.ammo_name[current_surface]
        global.ammo_count[surface_index] = global.ammo_count[current_surface]
        global.desired_robot_count[surface_index] = global.desired_robot_count[current_surface]
        global.desired_robot_name[surface_index] = global.desired_robot_name[current_surface]
        global.repair_tool_name[surface_index] = global.repair_tool_name[current_surface]
    end
end

return gui_handlers
