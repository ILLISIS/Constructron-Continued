-------------------------------------------------------------------------------
-- new globals
-------------------------------------------------------------------------------

global.station_combinators = {}
global.constructron_requests = {}
global.available_ctron_count = {}

-------------------------------------------------------------------------------
-- upgrade existing stations with combinators
-------------------------------------------------------------------------------

for _, station in pairs(global.service_stations) do
    local control_behavior = station.get_or_create_control_behavior()
    control_behavior.read_logistics = false
    local combinator = station.surface.create_entity{
        name = "ctron-combinator",
        position = {(station.position.x + 1), (station.position.y + 1)},
        direction = defines.direction.west,
        force = station.force,
        raise_built = true
    }
    local circuit1 = { wire = defines.wire_type.red, target_entity = station }
    local circuit2 = { wire = defines.wire_type.green, target_entity = station }
    combinator.connect_neighbour(circuit1)
    combinator.connect_neighbour(circuit2)
    global.station_combinators[station.unit_number] = {entity = combinator, signals = {}}
end

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

game.print('Constructron-Continued: v1.1.10 migration complete!')
game.print('Due to major internal changes, a full reset has been performed.')