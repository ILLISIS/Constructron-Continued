local ctron = require("__Constructron-Continued__.script.constructron")

script.on_init(ctron.on_init)
script.on_configuration_changed(ctron.on_configuration_changed)

-- ToDo rename called functions for on_nth_tick based on implemented feature instead of timer
script.on_nth_tick(1, ctron.on_nth_tick)
script.on_nth_tick(60, ctron.on_nth_tick_60)
script.on_nth_tick(54000, ctron.on_nth_tick_54000)

local ev = defines.events
script.on_event(ev.on_script_path_request_finished, ctron.on_script_path_request_finished)

-- ToDo: merge handlers for on_built_entity,script_raised_built,on_robot_built_entity
script.on_event(ev.on_built_entity, ctron.on_built_entity)
script.on_event(ev.script_raised_built, ctron.on_script_raised_built)
script.on_event(ev.on_robot_built_entity, ctron.on_robot_built_entity)

-- ToDo check if upgrade, built and deconstruct can be handled by the same logic, possibly a common  processing function with 2 different preprocessors/wrappers for each event if required
script.on_event(ev.on_marked_for_upgrade, ctron.on_marked_for_upgrade)

script.on_event(ev.on_marked_for_deconstruction, ctron.on_entity_marked_for_deconstruction, {{
    filter = 'name',
    name = "item-on-ground",
    invert = true
}})

script.on_event(ev.on_surface_created, ctron.on_surface_created)
script.on_event(ev.on_surface_deleted, ctron.on_surface_deleted)

script.on_event(ev.on_entity_cloned, ctron.on_entity_cloned)

-- ToDo: merge handlers for on_entity_destroyed, on_script_raised_destroy, check if on_post_entity_died is similiar
script.on_event(ev.on_entity_destroyed, ctron.on_entity_destroyed)
script.on_event(ev.script_raised_destroy, ctron.on_script_raised_destroy)
script.on_event(ev.on_post_entity_died, ctron.on_post_entity_died)
