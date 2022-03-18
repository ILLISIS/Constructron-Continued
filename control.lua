local ctron = require("__Constructron-Continued__.script.constructron")
local Spidertron_Pathfinder = require("__Constructron-Continued__.script.Spidertron-pathfinder")
ctron.pathfinder = Spidertron_Pathfinder()

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
    Spidertron_Pathfinder:on_script_path_request_finished(event)
end))

script.on_event({ev.on_built_entity, ev.script_raised_built, ev.on_robot_built_entity}, ctron.on_built_entity)

-- ToDo check if upgrade, built and deconstruct can be handled by the same logic, possibly a common processing function with 2 different preprocessors/wrappers for each event if required
script.on_event(ev.on_marked_for_upgrade, ctron.on_marked_for_upgrade)
script.on_event(ev.on_marked_for_deconstruction, ctron.on_entity_marked_for_deconstruction, {{
    filter = 'name',
    name = "item-on-ground",
    invert = true
}})

script.on_event(ev.on_surface_created, ctron.on_surface_created)
script.on_event(ev.on_surface_deleted, ctron.on_surface_deleted)
script.on_event(ev.on_entity_cloned, ctron.on_entity_cloned)
script.on_event({ev.on_entity_destroyed, ev.script_raised_destroy}, ctron.on_entity_destroyed)
script.on_event(ev.on_post_entity_died, ctron.on_post_entity_died)
script.on_event(ev.on_entity_damaged, ctron.on_entity_damaged)
