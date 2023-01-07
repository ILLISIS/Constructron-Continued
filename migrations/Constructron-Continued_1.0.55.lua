--So, when path cache is enabled, negative path cache is also enabled.
--The problem is, when a single unit inside a nest can't get to the silo,
--He tells all other biters nearby that they also can't get to the silo.
--Which causes whole groups of them just to chillout and idle...
--This applies to all paths as the pathfinder is generic - Klonan
game.map_settings.path_finder.use_path_cache = false
global.spider_remote_toggle = false

local cmd = require("script/command_functions")

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

game.print('Constructron-Continued: v1.0.55 migration complete!')
game.print('Due to major internal changes, a full reset has been performed.')