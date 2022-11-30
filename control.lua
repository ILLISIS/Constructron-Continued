local custom_lib = require("script/custom_lib")
local ctron = require("script/constructron")
local pathfinder = require("script/pathfinder")
local cmd = require("script/command_functions")
local chunk_util = require("script/chunk_util")
local entity_proc = require("script/entity_processor")

local gui = require("script/gui")
local gui_handler = require("script/gui_handler")

local init = function()
    ctron.ensure_globals()
    pathfinder.init_globals()
    
    gui.init()
    gui_handler.init(gui)
end

local load = function()
    gui_handler.init(gui)
end

script.on_init(init)
script.on_load(load)
script.on_configuration_changed(init)

script.on_nth_tick(15, (function(event)
    if event.tick % 20 == 15 then
        entity_proc.add_entities_to_chunks("deconstruction", global.deconstruction_entities, global.deconstruct_queue, global.deconstruct_marked_tick)
    elseif event.tick % 20 == 10 then
        entity_proc.add_entities_to_chunks("construction", global.ghost_entities, global.construct_queue, global.ghost_tick)
    elseif event.tick % 20 == 5 then
        entity_proc.add_entities_to_chunks("upgrade", global.upgrade_entities, global.upgrade_queue, global.upgrade_marked_tick)
    elseif event.tick % 20 == 0 then
        entity_proc.add_entities_to_chunks("repair", global.repair_entities, global.repair_queue, global.repair_marked_tick)
    end
end))

-- Spidertron waypoint orbit countermeasure
script.on_nth_tick(1, (function()
    for i, job_bundle in pairs(global.job_bundles) do
        local job = job_bundle[1]
        if job and job.action == "go_to_position" then
            if job.constructron and job.constructron.valid then
                local constructron = job.constructron
                if constructron.autopilot_destination then
                    if (constructron.speed > 0.5) then  -- 0.5 tiles per second is about the fastest a spider can move with 5 vanilla Exoskeletons.
                        local distance = chunk_util.distance_between(constructron.position, constructron.autopilot_destination)
                        local last_distance = job.wp_last_distance
                        if distance < 1 or (last_distance and distance > last_distance) then
                            constructron.stop_spider()
                            job.wp_last_distance = nil
                        else
                            job.wp_last_distance = distance
                        end
                    end
                end
            end
        end
    end
end))

-- main worker
script.on_nth_tick(60, ctron.process_job_queue)

-- cleanup
script.on_nth_tick(54000, (function(event)
    ctron.perform_surface_cleanup(event)
    -- pathfinder.check_pathfinder_requests_timeout()
end))

local ev = defines.events
script.on_event(ev.on_surface_created, ctron.on_surface_created)
script.on_event(ev.on_surface_deleted, ctron.on_surface_deleted)

script.on_event(ev.on_entity_cloned, ctron.on_entity_cloned)
script.on_event({ev.on_entity_destroyed, ev.script_raised_destroy}, ctron.on_entity_destroyed)

script.on_event(ev.on_runtime_mod_setting_changed, ctron.mod_settings_changed)

script.on_event(ev.on_player_created, gui.init)
gui_handler.register()

script.on_event(ev.on_player_used_spider_remote, (function(event)
    if global.spider_remote_toggle and event.vehicle.name == "constructron" then
        pathfinder.set_autopilot(event.vehicle, {})
        local request_params = {unit = event.vehicle, goal = event.position}
        pathfinder.request_path(request_params)
    end
end))
-------------------------------------------------------------------------------

---@param player LuaPlayer
---@param parameters string[]
local function reset(player, parameters)
    log("control:reset")
    log("by player:" .. player.name)
    log("parameters: " .. serpent.block(parameters))

    if parameters[1] == "entities" then
        game.print('Reset entities. Entity detection will now start.')
        cmd.reload_entities()

    elseif parameters[1] == "settings" then
        game.print('Reset settings to default.')
        cmd.reset_settings()

    elseif parameters[1] == "recall" then
        game.print('Recalling Constructrons to station(s).')
        cmd.recall_ctrons()
    
    elseif parameters[1] == "gui" then
        game.print('Reset GUI.')
        gui.init()
        gui_handler.init(gui)

    elseif parameters[1] == "all" then
        game.print('Reset all parameters and queues complete.')

        -- Clear jobs/queues/entities
        global.job_bundles = {}
        cmd.clear_queues()

        -- Clear supporting globals
        global.stack_cache = {}
        cmd.rebuild_caches()

        -- Clear and reacquire Constructrons & Stations
        cmd.reload_entities()
        cmd.reload_ctron_status()
        cmd.reload_ctron_color()

        -- Recall Ctrons
        cmd.recall_ctrons()

        -- Clear Constructron inventory
        cmd.clear_ctron_inventory()

        -- Reacquire Deconstruction jobs
        cmd.reacquire_deconstruction_jobs()

        -- Reacquire Construction jobs
        cmd.reacquire_construction_jobs()

        -- Reacquire Upgrade jobs
        cmd.reacquire_upgrade_jobs()

        -- Reinitialize GUI
        gui.init()
        gui_handler.init(gui)

    else
        game.print('Command parameter does not exist.')
        cmd.help_text()
    end
end

---@param player LuaPlayer
---@param parameters string[]
local function clear(player, parameters)
    log("control:clear")
    log("by player:" .. player.name)
    log("parameters: " .. serpent.block(parameters))

    if parameters[1] == "all" then
        game.print('All jobs, queued jobs and unprocessed entities cleared.')
        cmd.clear_queues()
        cmd.reload_ctron_status()
        cmd.reload_ctron_color()
        global.job_bundles = {}
        cmd.recall_ctrons()

    elseif parameters[1] == "queues" then
        game.print('All queued jobs and unprocessed entities cleared.')
        cmd.clear_queues()

    elseif parameters[1] == "inventory" then
        game.print('All Constructron inventories will be reset')
        cmd.clear_ctron_inventory()

    else
        game.print('Command parameter does not exist.')
        cmd.help_text()
    end
end

---@param player LuaPlayer
---@param parameters string[]
local function enable(player, parameters)
    log("control:enable")
    log("by player:" .. player.name)
    log("parameters: " .. serpent.block(parameters))

    if parameters[1] == "construction" then
        global.construction_job_toggle = true
        settings.global["construct_jobs"] = {value = true}
        cmd.reload_entities()
        cmd.reacquire_construction_jobs()
        game.print('Construction jobs enabled.')

    elseif parameters[1] == "rebuild" then
        global.rebuild_job_toggle = true
        settings.global["rebuild_jobs"] = {value = true}
        game.print('Rebuild jobs enabled.')

    elseif parameters[1] == "deconstruction" then
        global.deconstruction_job_toggle = true
        settings.global["deconstruct_jobs"] = {value = true}
        cmd.reacquire_deconstruction_jobs()
        game.print('Deconstruction jobs enabled.')

    elseif parameters[1] == "ground_deconstruction" then
        global.ground_decon_job_toggle = true
        settings.global["decon_ground_items"] = {value = true}
        game.print('items-on-ground deconstruction enabled.')

    elseif parameters[1] == "upgrade" then
        global.upgrade_job_toggle = true
        settings.global["upgrade_jobs"] = {value = true}
        cmd.reacquire_upgrade_jobs()
        game.print('Upgrade jobs enabled.')

    elseif parameters[1] == "repair" then
        global.repair_job_toggle = true
        settings.global["repair_jobs"] = {value = true}
        game.print('Repair jobs enabled.')

    elseif parameters[1] == "debug" then
        global.debug_toggle = true
        settings.global["constructron-debug-enabled"] = {value = true}
        game.print('Debug view enabled.')

    elseif parameters[1] == "landfill" then
        game.print('Landfill is now permanently enabled.')

    elseif parameters[1] == "remote" then
        global.spider_remote_toggle = true
        game.print('Spider remote enabled.')
        if game.map_settings.path_finder.use_path_cache then
            game.print('use_path_cache = true')
        else
            game.print('use_path_cache = false')
        end

    else
        game.print('Command parameter does not exist.')
        cmd.help_text()
    end
end

---@param player LuaPlayer
---@param parameters string[]
local function disable(player, parameters)
    log("control:disable")
    log("by player:" .. player.name)
    log("parameters: " .. serpent.block(parameters))

    if parameters[1] == "construction" then
        global.construction_job_toggle = false
        settings.global["construct_jobs"] = {value = false}
        game.print('Construction jobs disabled.')

    elseif parameters[1] == "rebuild" then
        global.rebuild_job_toggle = false
        settings.global["rebuild_jobs"] = {value = false}
        game.print('Rebuild jobs disabled.')

    elseif parameters[1] == "deconstruction" then
        global.deconstruction_job_toggle = false
        settings.global["deconstruct_jobs"] = {value = false}
        game.print('Deconstruction jobs disabled.')

    elseif parameters[1] == "ground_deconstruction" then
        global.ground_decon_job_toggle = false
        settings.global["decon_ground_items"] = {value = false}
        game.print('items-on-ground deconstruction disabled.')

    elseif parameters[1] == "upgrade" then
        global.upgrade_job_toggle = false
        settings.global["upgrade_jobs"] = {value = false}
        game.print('Upgrade jobs disabled.')

    elseif parameters[1] == "repair" then
        global.repair_job_toggle = false
        settings.global["repair_jobs"] = {value = false}
        game.print('Repair jobs disabled.')

    elseif parameters[1] == "debug" then
        global.debug_toggle = false
        settings.global["constructron-debug-enabled"] = {value = false}
        game.print('Debug view disabled.')

    elseif parameters[1] == "landfill" then
        game.print('Landfill is now permanently enabled.')

    elseif parameters[1] == "remote" then
        global.spider_remote_toggle = false
        game.print('Spider remote disabled.')

    else
        game.print('Command parameter does not exist.')
        cmd.help_text()
    end
end

---@param player LuaPlayer
---@param _ string[]
local function stats(player, _)
    log("control:help")
    log("by player:" .. player.name)

    local global_stats = cmd.stats()
    log(serpent.block(global_stats))
    if global_stats and player then
        for k,v in pairs(global_stats) do
            player.print(k .. ": " .. tostring(v))
        end
    end
    return global_stats
end

---@param player LuaPlayer
---@param parameters string[]
local function help(player, parameters)
    log("control:help")
    log("by player:" .. player.name)
    log("parameters: " .. serpent.block(parameters))
    cmd.help_text()
end

--===========================================================================--
-- commands & interfaces
--===========================================================================--

local ctron_commands = {
    ["help"] = help,
    ["reset"] = reset,
    ["clear"] = clear,
    ["enable"] = enable,
    ["disable"] = disable,
    ["stats"] = stats
}

-------------------------------------------------------------------------------
-- commands
-------------------------------------------------------------------------------
commands.add_command(
    "ctron",
    "/ctron reset",
    function(param)
        log("/ctron " .. (param.parameter or ""))
        if param.parameter then
            local player = game.players[param.player_index] --[[@as LuaPlayer]]
            local params = custom_lib.string_split(param.parameter, " ")
            local command = table.remove(params, 1) --[[@as string]]
            if command and ctron_commands[command] then
                ctron_commands[command](player,params)
            else
                game.print('Command parameter does not exist.')
                cmd.help_text()
            end
        end
    end
)

-------------------------------------------------------------------------------
--- game interfaces
-------------------------------------------------------------------------------
remote.add_interface("ctron_interface", ctron_commands)
