local cmd = require("script/command_functions")
local utility_func = require("script/utility_functions")

storage = {}
storage.constructron_statuses = {}
storage.station_requests = {}
storage.ctron_combinators = {}
storage.registered_entities = {}

-------------------------------------------------------------------------------
-- combinator changes
-------------------------------------------------------------------------------

for _, surface in pairs(game.surfaces) do
    local surface_index = surface.index
    -- find and delete all combinators
    local entities = surface.find_entities_filtered { name = "ctron-combinator" }
    for _, entity in pairs(entities) do
        entity.destroy()
    end
    -- create new combinator at the first station found
    local stations = surface.find_entities_filtered { name = "service_station" }
    _, station = next(stations)
    if station and station.valid then
        local combinator = surface.create_entity {
            name = "ctron-combinator",
            position = {(station.position.x + 1), (station.position.y + 1)},
            direction = defines.direction.west,
            force = game.forces.player,
            raise_built = true
        }
        assert(combinator, "Migration - Failed to create combinator")
        storage.ctron_combinators[surface_index] = combinator
        local combinator_reg_number = script.register_on_object_destroyed(storage.ctron_combinators[surface_index])
        storage.registered_entities[combinator_reg_number] = {
            name = "ctron-combinator",
            surface = surface_index
        }
        -- connect all stations to the combinator
        local combinator_red_connector = combinator.get_wire_connector(defines.wire_connector_id.circuit_red, false)
        local combinator_green_connector = combinator.get_wire_connector(defines.wire_connector_id.circuit_green, false)
        for _, station in pairs(stations) do
            if station and station.valid then
                local station_red_connector = station.get_wire_connector(defines.wire_connector_id.circuit_red, false)
                local station_green_connector = station.get_wire_connector(defines.wire_connector_id.circuit_green, false)
                combinator_red_connector.connect_to(station_red_connector, false)
                combinator_green_connector.connect_to(station_green_connector, false)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- reset internals
-------------------------------------------------------------------------------
storage.pathfinder_requests = {}
-- Clear jobs/queues/entities
storage.jobs = {}
storage.job_index = 0
cmd.clear_queues()
-- Clear supporting storages
storage.stack_cache = {}
storage.entity_inventory_cache = {}
cmd.rebuild_caches()
-- Clear and reacquire Constructrons & Stations
cmd.reload_entities()
-- Recall Ctrons
cmd.recall_ctrons()

-------------------------------------------------------------------------------

game.print('Constructron-Continued: v2.0.0 migration complete!')
game.print('Due to major internal changes, a full reset has been performed.')