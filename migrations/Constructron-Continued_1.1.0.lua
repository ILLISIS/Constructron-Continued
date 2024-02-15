local cmd = require("script/command_functions")

-------------------------------------------------------------------------------
-- equivalent to reset all command
-------------------------------------------------------------------------------
global.pathfinder_requests = {}
game.print('Reset all parameters and queues complete.')
-- Clear jobs/queues/entities
global.jobs = {}
global.job_index = 0
cmd.clear_queues()
-- Clear supporting globals
global.stack_cache = {}
global.entity_inventory_cache = {}
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

----

if not game.item_prototypes[settings.global["desired_robot_name"].value] then
    if game.item_prototypes["construction-robot"] then
        settings.global["desired_robot_name"] = {value = "construction-robot"}
        global.desired_robot_name = "construction-robot"
        game.print("Constructron-Continued: **WARNING** desired_robot_name is not a valid name in mod settings! Robot name reset!")
    else
        local valid_robots = game.get_filtered_entity_prototypes{{filter = "type", type = "construction-robot"}}
        local valid_robot_name = pairs(valid_robots)(nil,nil)
        settings.global["desired_robot_name"] = {value = valid_robot_name}
        game.print("Constructron-Continued: **WARNING** desired_robot_name is not a valid name in mod settings! Robot name reset!")
    end
else
    global.desired_robot_name = settings.global["desired_robot_name"].value
end

-------------------------------------------------------------------------------
-- deprecated globals
-------------------------------------------------------------------------------
global.job_bundles = nil
global.job_bundle_index = nil

global.deconstruct_marked_tick = nil
global.ghost_tick = nil
global.upgrade_marked_tick = nil
global.repair_marked_tick = nil

global.ghost_entities = nil

global.deconstruct_queue = nil
global.construct_queue = nil

global.pathfinder_queue = nil
global.path_queue_trigger = nil

-------------------------------------------------------------------------------

game.print('Constructron-Continued: v1.1.0 migration complete!')
game.print('Due to major internal changes, a full reset has been performed.')