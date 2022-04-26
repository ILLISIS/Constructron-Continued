local custom_lib = require("__Constructron-Continued__.script.custom_lib")
local ctron = require("__Constructron-Continued__.script.constructron")
local Spidertron_Pathfinder = require("__Constructron-Continued__.script.Spidertron-pathfinder")

ctron.pathfinder = Spidertron_Pathfinder

local init = function()
    ctron.ensure_globals()
    Spidertron_Pathfinder.init_globals()
end

script.on_init(init)
script.on_configuration_changed(init)

-- Possibly do this at a 10x lower frequency or controlled by a mod setting
script.on_nth_tick(1, (function(event)
    if event.tick % 300 == 0 then
        ctron.setup_constructrons()
    elseif event.tick % 20 == 0 then
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
if (settings.startup["construct_jobs"].value) then
    script.on_event({ev.on_built_entity, ev.script_raised_built, ev.on_robot_built_entity}, ctron.on_built_entity)
end

if (settings.startup["rebuild_jobs"].value) then
    script.on_event(ev.on_post_entity_died, ctron.on_post_entity_died)
end

if (settings.startup["deconstruct_jobs"].value) then
    if settings.startup["decon_ground_items"].value then
        script.on_event(ev.on_marked_for_deconstruction, ctron.on_entity_marked_for_deconstruction)
    else
        script.on_event(ev.on_marked_for_deconstruction, ctron.on_entity_marked_for_deconstruction, {
            {filter = 'name', name = "item-on-ground", invert = true}
        })
    end
end

if (settings.startup["upgrade_jobs"].value) then
    script.on_event(ev.on_marked_for_upgrade, ctron.on_marked_for_upgrade)
end

if (settings.startup["repair_jobs"].value) then
    script.on_event(ev.on_entity_damaged, ctron.on_entity_damaged, {
        {filter = "final-health", comparison = ">", value = 0, mode = "and"},
        {filter = "robot-with-logistics-interface", invert = true, mode = "and"},
        {filter = "vehicle", invert = true, mode = "and"},
        {filter = "rolling-stock", invert = true, mode = "and"},
        {filter = "type", type = "character", invert = true, mode = "and"}
    })
end

script.on_event(ev.on_surface_created, ctron.on_surface_created)
script.on_event(ev.on_surface_deleted, ctron.on_surface_deleted)

script.on_event(ev.on_entity_cloned, ctron.on_entity_cloned)
script.on_event({ev.on_entity_destroyed, ev.script_raised_destroy}, ctron.on_entity_destroyed)

-------------------------------------------------------------------------------
local function reset(player, parameters)
    log("control:reset")
    log("by player:" .. player.name)
    log("parameters: " .. serpent.block(parameters))
    game.print("Constructron: !!! reset !!!", {r = 1, g = 0.2, b = 0.2})
    game.print("warning: present ghosts might be ignored", {r = 1, g = 0.2, b = 0.2})
    for _, surface in pairs(game.surfaces) do
        ctron.force_surface_cleanup(surface)
    end
end

--===========================================================================--
-- commands & interfaces
--===========================================================================--

local ctron_commands = {
    reset = reset,
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
            end
        end
    end
)

-------------------------------------------------------------------------------
--- game interfaces
-------------------------------------------------------------------------------
remote.add_interface("ctron_interface", ctron_commands)
