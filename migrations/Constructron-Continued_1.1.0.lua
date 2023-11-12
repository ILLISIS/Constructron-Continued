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