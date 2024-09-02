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
cmd.reset_available_ctron_count()
cmd.reload_ctron_status()
cmd.reload_ctron_color()
-- Recall Ctrons
cmd.recall_ctrons()
-- Reset combinators
cmd.reset_combinator_signals()
-- Clear Constructron inventory
cmd.clear_ctron_inventory()
-- Reacquire Deconstruction jobs
cmd.reacquire_deconstruction_jobs()
-- Reacquire Construction jobs
cmd.reacquire_construction_jobs()
-- Reacquire Upgrade jobs
cmd.reacquire_upgrade_jobs()

-------------------------------------------------------------------------------

game.print('Constructron-Continued: v1.1.24 migration complete!')
game.print('Due to major internal changes, a full reset has been performed.')