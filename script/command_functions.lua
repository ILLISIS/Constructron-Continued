local util_func = require("script/utility_functions")

local me = {}

-- me.reset_settings = function()
--     storage.construction_job_toggle = {}
--     storage.rebuild_job_toggle = {}
--     storage.deconstruction_job_toggle = {}
--     storage.upgrade_job_toggle = {}
--     storage.repair_job_toggle = {}
--     storage.destroy_job_toggle = {}
--     local init_ammo_name
--     storage.ammo_name = {}
--     if game.item_prototypes["rocket"] then
--         init_ammo_name = "rocket"
--     else
--         local ammo_prototypes = game.get_filtered_item_prototypes{{filter = "type", type = "ammo"}}
--         for _, ammo in pairs(ammo_prototypes) do
--             local ammo_type = ammo.get_ammo_type() or {}
--             if ammo_type.category == "rocket" then
--                 init_ammo_name = ammo.name
--             end
--         end
--     end
--     storage.ammo_count = {}
--     storage.desired_robot_count = {}
--     local init_robot_name
--     storage.desired_robot_name = {}
--     if game.item_prototypes["construction-robot"] then
--         init_robot_name = "construction-robot"
--     else
--         local valid_robots = game.get_filtered_entity_prototypes{{filter = "type", type = "construction-robot"}}
--         local valid_robot_name = util_func.firstoflct(valid_robots)
--         init_robot_name = valid_robot_name
--     end
--     local init_repair_tool_name
--     if storage.repair_tool_name == nil or not game.item_prototypes[storage.repair_tool_name[1]] then
--         storage.repair_tool_name = {}
--         if game.item_prototypes["repair-pack"] then
--             init_repair_tool_name = "repair-pack"
--         else
--             local valid_repair_tools = game.get_filtered_item_prototypes{{filter = "type", type = "repair-tool"}}
--             local valid_repair_tool_name = util_func.firstoflct(valid_repair_tools)
--             init_repair_tool_name = valid_repair_tool_name
--         end
--     end
--     -- non surface specific settings
--     storage.job_start_delay = 300 -- five seconds
--     storage.entities_per_second = 1000
--     storage.debug_toggle = false
--     storage.horde_mode = false
--     -- set per surface setting values
--     for _, surface in pairs(game.surfaces) do
--         -- per surface settings
--         local surface_index = surface.index
--         storage.construction_job_toggle[surface_index] = true
--         storage.rebuild_job_toggle[surface_index] = true
--         storage.deconstruction_job_toggle[surface_index] = true
--         storage.upgrade_job_toggle[surface_index] = true
--         storage.repair_job_toggle[surface_index] = true
--         storage.destroy_job_toggle[surface_index] = false
--         storage.ammo_name[surface_index] = init_ammo_name
--         storage.ammo_count[surface_index] = 0
--         storage.desired_robot_count[surface_index] = 50
--         storage.desired_robot_name[surface_index] = init_robot_name
--         storage.repair_tool_name[surface_index] = init_repair_tool_name
--     end
-- end

me.clear_queues = function()
    storage.construction_entities = {}
    storage.deconstruction_entities = {}
    storage.upgrade_entities = {}
    storage.repair_entities = {}
    storage.destroy_entities = {}

    storage.construction_index = 0
    storage.deconstruction_index = 0
    storage.upgrade_index = 0
    storage.repair_index = 0
    storage.destroy_index = 0
    storage.cargo_index = 0

    storage.construction_queue = {}
    storage.deconstruction_queue = {}
    storage.upgrade_queue = {}
    storage.repair_queue = {}
    storage.destroy_queue = {}
    storage.cargo_queue = {}

    for _, surface in pairs(game.surfaces) do
        storage.construction_queue[surface.index] = storage.construction_queue[surface.index] or {}
        storage.deconstruction_queue[surface.index] = storage.deconstruction_queue[surface.index] or {}
        storage.upgrade_queue[surface.index] = storage.upgrade_queue[surface.index] or {}
        storage.repair_queue[surface.index] = storage.repair_queue[surface.index] or {}
        storage.destroy_queue[surface.index] = storage.destroy_queue[surface.index] or {}
        storage.cargo_queue[surface.index] = storage.cargo_queue[surface.index] or {}
    end
end

me.clear_single_job_type = function(job_type)
    global[job_type .. '_entities'] = {}
    global[job_type ..'_index'] = 0
    global[job_type .. '_queue'] = {}
    for _, surface in pairs(game.surfaces) do
        global[job_type .. '_queue'][surface.index] = {}
    end
end

me.reload_entities = function()
    storage.service_stations = {}
    storage.constructrons = {}
    storage.station_combinators = {}

    storage.stations_count = {}
    storage.constructrons_count = {}
    storage.available_ctron_count = {}

    me.reacquire_ctrons()
    me.reacquire_stations()

    -- determine managed surfaces
    me.reset_managed_surfaces()
end

me.reset_managed_surfaces = function()
    storage.managed_surfaces = {}
    for _, surface in pairs(game.surfaces) do
        local surface_index = surface.index
        if (storage.constructrons_count[surface_index] > 0) and (storage.stations_count[surface_index] > 0) then
            storage.managed_surfaces[surface_index] = game.surfaces[surface_index].name
        else
            storage.managed_surfaces[surface_index] = nil
        end
    end
end

me.reacquire_stations = function()
    for _, surface in pairs(game.surfaces) do
        storage.stations_count[surface.index] = 0
        local stations = surface.find_entities_filtered {
            name = "service_station",
            force = "player",
            surface = surface.name
        }

        for _, station in pairs(stations) do
            local unit_number = station.unit_number ---@cast unit_number -nil
            if not storage.service_stations[unit_number] then
                storage.service_stations[unit_number] = station
            end

            local registration_number = script.register_on_object_destroyed(station)
            storage.registered_entities[registration_number] = {
                name = "service_station",
                surface = surface.index
            }
            storage.station_requests[unit_number] = {}
            storage.stations_count[surface.index] = storage.stations_count[surface.index] + 1
        end
    game.print('Registered ' .. storage.stations_count[surface.index] .. ' stations on ' .. surface.name .. '.')
    end
end

local ctron_entities = { "constructron", "constructron-rocket-powered" }
if not prototypes.entity["constructron-rocket-powered"] then
    ctron_entities = {"constructron"}
end

me.reacquire_ctrons = function()
    for _, surface in pairs(game.surfaces) do
        storage.constructrons_count[surface.index] = 0
        local constructrons = surface.find_entities_filtered {
            name = ctron_entities,
            force = "player",
            surface = surface.name
        }

        for _, constructron in pairs(constructrons) do
            local unit_number = constructron.unit_number ---@cast unit_number -nil
            if not storage.constructrons[unit_number] then
                storage.constructrons[unit_number] = constructron
            end

            local registration_number = script.register_on_object_destroyed(constructron)
            storage.registered_entities[registration_number] = {
                name = "constructron",
                surface = surface.index
            }

            -- Reset Hardcodes
            constructron.grid.inhibit_movement_bonus = false

            local grid = constructron.grid     if grid then
                for _, eq in next, grid.equipment do
                    if eq.type == "roboport-equipment" then
                        local old_eq_name = eq.prototype.take_result.name
                        local old_eq_pos = eq.position
                        local old_eq_energy = eq.energy
                        grid.take{ position = eq.position }
                        local new_set = grid.put{ name = old_eq_name, position = old_eq_pos }
                        if new_set then
                            new_set.energy = old_eq_energy
                        end
                    end
                end
            end

            storage.constructrons_count[surface.index] = (storage.constructrons_count[surface.index] or 0) + 1
            storage.available_ctron_count[surface.index] = (storage.available_ctron_count[surface.index] or 0) + 1
            storage.constructron_statuses[constructron.unit_number] = { busy = false }
        end
        game.print('Registered ' .. storage.constructrons_count[surface.index] .. ' constructrons on ' .. surface.name .. '.')
    end
end

me.recall_ctrons = function()
    for _, surface in pairs(game.surfaces) do
        if (storage.stations_count[surface.index] > 0) and (storage.constructrons_count[surface.index] > 0) then
            local constructrons = surface.find_entities_filtered {
                name = ctron_entities,
                force = "player",
                surface = surface.name
            }
            for _, constructron in pairs(constructrons) do
                constructron.autopilot_destination = nil
                local closest_station = util_func.get_closest_service_station(constructron)
                if closest_station then
                    storage.job_index = storage.job_index + 1
                    storage.jobs[storage.job_index] = utility_job.new(storage.job_index, constructron.surface.index, "utility", constructron)
                    storage.jobs[storage.job_index].state = "finishing"
                    storage.job_proc_trigger = true -- start job operations
                end
            end
        else
            game.print('No stations to recall Constructrons to on ' .. surface.name .. '.')
        end
    end
end

me.reset_available_ctron_count = function()
    storage.available_ctron_count = {}
    for _, surface in pairs(game.surfaces) do
        storage.available_ctron_count[surface.index] = storage.constructrons_count[surface.index]
    end
end

me.rebuild_caches = function()
    -- build allowed items cache (used in add_entities_to_chunks)
    storage.allowed_items = {}
    for item_name, _ in pairs(prototypes.item) do
        local recipes = prototypes.get_recipe_filtered({
                {filter = "has-product-item", elem_filters = {{filter = "name", name = item_name}}},
            })
        for _ , recipe in pairs(recipes) do
            if not game.forces["player"].recipes[recipe.name].hidden then -- if the recipe is hidden disallow it
                storage.allowed_items[item_name] = true
            end
        end
        if storage.allowed_items[item_name] == nil then -- some items do not have recipes so set the item to disallowed
            storage.allowed_items[item_name] = false
        end
    end
    local autoplace_entities = prototypes.get_entity_filtered{{filter="autoplace"}}
    for entity_name, entity in pairs(autoplace_entities) do
        if entity.mineable_properties and entity.mineable_properties.products then
            storage.allowed_items[entity_name] = true
        end
    end
    -- allowed_items overrides as item/entities do not match what is mined (this is particularly for cargo jobs)
    storage.allowed_items["raw-fish"] = true
    storage.allowed_items["wood"] = true
    -- build required_items cache (used in add_entities_to_chunks)
    storage.items_to_place_cache = {}
    for name, v in pairs(prototypes.entity) do
        if v.items_to_place_this ~= nil and v.items_to_place_this[1] and v.items_to_place_this[1].name then -- bots will only ever use the first item from this list
            storage.items_to_place_cache[name] = {item = v.items_to_place_this[1].name, count = v.items_to_place_this[1].count}
        end
    end
    for name, v in pairs(prototypes.tile) do
        if v.items_to_place_this ~= nil and v.items_to_place_this[1] and v.items_to_place_this[1].name then -- bots will only ever use the first item from this list
            storage.items_to_place_cache[name] = {item = v.items_to_place_this[1].name, count = v.items_to_place_this[1].count}
        end
    end
    -- build trash_items_cache
    storage.trash_items_cache = {}
    for entity_name, prototype in pairs(prototypes.entity) do
        if prototype.mineable_properties and prototype.mineable_properties.products then
            for _, product in pairs(prototype.mineable_properties.products) do
                if product.type == "item" then
                    storage.trash_items_cache[entity_name] = storage.trash_items_cache[entity_name] or {}
                    storage.trash_items_cache[entity_name][product.name] = product.amount_max or product.amount
                end
            end
        else
            storage.trash_items_cache[entity_name] = {}
        end
    end
    -- build water tile cache
    storage.water_tile_cache = {}
    local water_tile_prototypes = prototypes.get_tile_filtered{{filter="collision-mask",mask={layers ={["water_tile"]=true}},mask_mode="contains-any"}}
    for tile_name, _ in pairs(water_tile_prototypes) do
        storage.water_tile_cache[tile_name] = true
    end
end

me.stats = function()
    local queues = {
        "registered_entities",
        "constructron_statuses",
        "construction_entities",
        "deconstruction_entities",
        "destroy_entities",
        "upgrade_entities",
        "repair_entities",
        "jobs",
        "constructrons",
        "service_stations",
    }
    local global_stats = {
    }
    for _, data_name in pairs(queues) do
        local data = global[data_name]
        if type(data)=="table" then
            global_stats[data_name] = table_size(data)
        else
            global_stats[data_name] = tostring(data)
        end
    end
    local surface_queues = {
        "constructrons_count",
        "stations_count",
        "construction_queue",
        "deconstruction_queue",
        "upgrade_queue",
        "repair_queue",
        "destroy_queue",
    }
    for _, surface in pairs(game.surfaces) do
        for _, data_name in pairs(surface_queues) do
            local data = global[data_name][surface.index]
            if type(data)=="table" then
                -- log(serpent.block(data))
                global_stats[surface.name .. ": " .. data_name] = table_size(data)
            else
                global_stats[surface.name .. ":" .. data_name] = tostring(data)
            end
        end
    end
    return global_stats
end

me.help_text = function()
    game.print('Constructron-Continued command help:')
    game.print('/ctron help - show this help message')
    game.print('/ctron reset (settings|queues|entities|all)')
    game.print('/ctron clear (all|construction|deconstruction|upgrade|repair|destroy)')
    game.print('/ctron stats for a basic display of queue length')
    game.print('See Factorio mod portal for further assistance https://mods.factorio.com/mod/Constructron-Continued')
end

return me