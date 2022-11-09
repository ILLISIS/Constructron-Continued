local custom_lib = require("__Constructron-Continued__.script.custom_lib")
local ctron = require("__Constructron-Continued__.script.constructron")
local Spidertron_Pathfinder = require("__Constructron-Continued__.script.Spidertron-pathfinder")
local cmd = require("__Constructron-Continued__.script.command_functions")

ctron.pathfinder = Spidertron_Pathfinder

local init = function()
    ctron.ensure_globals()
    Spidertron_Pathfinder.init_globals()
end

script.on_init(init)
script.on_configuration_changed(init)

-- Possibly do this at a 10x lower frequency or controlled by a mod setting
script.on_nth_tick(1, (function(event)
    if event.tick % 20 == 0 then
        ctron.add_entities_to_chunks("deconstruction")
    elseif event.tick % 20 == 5 then
        ctron.add_entities_to_chunks("ghost")
    elseif event.tick % 20 == 10 then
        ctron.add_entities_to_chunks("upgrade")
    elseif event.tick % 20 == 15 then
        ctron.add_entities_to_chunks("repair")
    end
end))
-- main worker
script.on_nth_tick(60, ctron.process_job_queue)
-- cleanup
script.on_nth_tick(54000, (function(event)
    ctron.perform_surface_cleanup(event)
    Spidertron_Pathfinder.check_pathfinder_requests_timeout()
end))

local ev = defines.events
script.on_event(ev.on_script_path_request_finished, (function(event)
    Spidertron_Pathfinder.on_script_path_request_finished(event)
end))

-- ToDo check if upgrade, built and deconstruct can be handled by the same logic, possibly a common processing function with 2 different preprocessors/wrappers for each event if required
script.on_event(ev.on_built_entity, ctron.on_built_entity, {
    {filter = "name", name = "constructron", mode = "or"},
    {filter = "force",  force = "player", mode = "and"},
    {filter = "name", name = "constructron-rocket-powered", mode = "or"},
    {filter = "force",  force = "player", mode = "and"},
    {filter = "name", name = "service_station", mode = "or"},
    {filter = "force",  force = "player", mode = "and"},
    {filter = "name", name = "entity-ghost", mode = "or"},
    {filter = "force",  force = "player", mode = "and"},
    {filter = "name", name = "tile-ghost", mode = "or"},
    {filter = "force",  force = "player", mode = "and"},
    {filter = "name", name = "item-request-proxy", mode = "or"},
    {filter = "force",  force = "player", mode = "and"}
})

script.on_event(ev.on_robot_built_entity, ctron.on_built_entity, {
    {filter = "name", name = "service_station", mode = "or"}
})

script.on_event(ev.script_raised_built, ctron.on_built_entity, {
    {filter = "name", name = "constructron", mode = "or"},
    {filter = "name", name = "constructron-rocket-powered", mode = "or"},
    {filter = "name", name = "service_station", mode = "or"},
    {filter = "name", name = "entity-ghost", mode = "or"},
    {filter = "name", name = "tile-ghost", mode = "or"},
    {filter = "name", name = "item-request-proxy", mode = "or"}
})

script.on_event(ev.on_post_entity_died, ctron.on_post_entity_died)


script.on_event(ev.on_marked_for_deconstruction, ctron.on_entity_marked_for_deconstruction)


script.on_event(ev.on_marked_for_upgrade, ctron.on_marked_for_upgrade)

script.on_event(ev.on_entity_damaged, ctron.on_entity_damaged, {
    {filter = "final-health", comparison = ">", value = 0, mode = "and"},
    {filter = "robot-with-logistics-interface", invert = true, mode = "and"},
    {filter = "vehicle", invert = true, mode = "and"},
    {filter = "rolling-stock", invert = true, mode = "and"},
    {filter = "type", type = "character", invert = true, mode = "and"},
    {filter = "type", type = "fish", invert = true, mode = "and"}
})

script.on_event(ev.on_surface_created, ctron.on_surface_created)
script.on_event(ev.on_surface_deleted, ctron.on_surface_deleted)

script.on_event(ev.on_entity_cloned, ctron.on_entity_cloned)
script.on_event({ev.on_entity_destroyed, ev.script_raised_destroy}, ctron.on_entity_destroyed)

script.on_event(ev.on_runtime_mod_setting_changed, ctron.mod_settings_changed)
-------------------------------------------------------------------------------
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

    elseif parameters[1] == "all" then
        game.print('Reset all parameters and queues complete.')

        -- Clear jobs/queues/entities
        global.job_bundles = {}
        cmd.clear_queues()

        -- Clear supporting globals
        global.ignored_entities = {}
        global.allowed_items = {}
        global.stack_cache = {}

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

    else
        game.print('Command parameter does not exist.')
        cmd.help_text()
    end
end

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

local function enable(player, parameters)
    log("control:enable")
    log("by player:" .. player.name)
    log("parameters: " .. serpent.block(parameters))

    if parameters[1] == "construction" then
        global.construction_job_toggle = true
        settings.global["construct_jobs"] = {value = true}
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
        global.landfill_job_toggle = true
        settings.global["allow_landfill"] = {value = true}
        game.print('Landfill enabled.')

    else
        game.print('Command parameter does not exist.')
        cmd.help_text()
    end
end

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
        global.landfill_job_toggle = false
        settings.global["allow_landfill"] = {value = false}
        game.print('Landfill disabled.')

    else
        game.print('Command parameter does not exist.')
        cmd.help_text()
    end
end

local function stats(player, _ )
    log("control:help")
    log("by player:" .. player.name)

    local stats = cmd.stats()
    log(serpent.block(stats))
    if stats and player then
        for k,v in pairs(stats) do
            player.print(k .. ": " .. tostring(v))
        end
    end
    return stats
end

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
    help = help,
    reset = reset,
    clear = clear,
    enable = enable,
    disable = disable,
    stats = stats
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
            local player = game.players[param.player_index]
            local params = custom_lib.string_split(param.parameter, " ")
            local command = table.remove(params, 1)
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
