local util_func = require("script/utility_functions")
local debug_lib = require("script/debug_lib")
local job_proc = require("script/job_processor")

local entity_proc = {}

-------------------------------------------------------------------------------
--  Event handlers
-------------------------------------------------------------------------------
local ev = defines.events

-- for entity creation
---@param event
---| EventData.on_built_entity
---| EventData.on_robot_built_entity
---| EventData.script_raised_built
entity_proc.on_built_entity = function(event)
    local entity = event.created_entity or event.entity
    local entity_type = entity.type
    local surface_index = entity.surface.index
    if global.construction_job_toggle[surface_index] and (entity_type == 'entity-ghost' or entity_type == 'tile-ghost' or entity_type == 'item-request-proxy') then
        global.construction_index = global.construction_index + 1
        global.construction_entities[global.construction_index] = entity
        global.construction_tick = event.tick
        global.entity_proc_trigger = true -- there is something to do start processing
    elseif entity.name == 'constructron' or entity.name == "constructron-rocket-powered" then -- register constructron
        local registration_number = script.register_on_entity_destroyed(entity)
        util_func.set_constructron_status(entity, 'busy', false)
        util_func.paint_constructron(entity, 'idle')
        entity.enable_logistics_while_moving = false
        global.constructrons[entity.unit_number] = entity
        global.registered_entities[registration_number] = {
            name = "constructron",
            surface = surface_index
        }
        global.constructrons_count[surface_index] = global.constructrons_count[surface_index] + 1
        global.available_ctron_count[surface_index] = global.available_ctron_count[surface_index] + 1
        -- combinator related
        global.constructron_requests[entity.unit_number] = {}
        global.constructron_requests[entity.unit_number].requests = {}
        for _, station in pairs(global.service_stations) do
            util_func.update_combinator(station, "constructron_pathing_proxy_1", 0)
        end
        -- utility
        if (global.stations_count[surface_index] > 0) then
            global.managed_surfaces[surface_index] = entity.surface.name
        end
        entity.vehicle_automatic_targeting_parameters = {
            auto_target_without_gunner = true,
            auto_target_with_gunner = true
        }
    elseif entity.name == "service_station" then -- register service station
        local registration_number = script.register_on_entity_destroyed(entity)
        global.service_stations[entity.unit_number] = entity
        global.registered_entities[registration_number] = {
            name = "service_station",
            surface = surface_index
        }
        global.stations_count[surface_index] = global.stations_count[surface_index] + 1
        if (global.constructrons_count[surface_index] > 0) then
            global.managed_surfaces[surface_index] = entity.surface.name
        end
        -- combinator setup
        local control_behavior = entity.get_or_create_control_behavior()
        control_behavior.read_logistics = false
        local combinator = entity.surface.create_entity{
            name = "ctron-combinator",
            position = {(entity.position.x + 1), (entity.position.y + 1)},
            direction = defines.direction.west,
            force = entity.force,
            raise_built = true
        } ---@cast combinator -nil
        local circuit1 = { wire = defines.wire_type.red, target_entity = entity }
        local circuit2 = { wire = defines.wire_type.green, target_entity = entity }
        combinator.connect_neighbour(circuit1)
        combinator.connect_neighbour(circuit2)
        local signals = {
            [1] = {index = 1, signal = {type = "virtual", name = "signal-C"}, count = global.constructrons_count[entity.surface.index]},
            [2] = {index = 2, signal = {type = "virtual", name = "signal-A"}, count = global.available_ctron_count[entity.surface.index]}
        }
        global.station_combinators[entity.unit_number] = {entity = combinator, signals = {}}
        combinator.get_control_behavior().parameters = signals
        global.station_requests[entity.unit_number] = {}
    end
end

script.on_event(ev.on_built_entity, entity_proc.on_built_entity, {
    {filter = "name", name = "constructron", mode = "or"},
    {filter = "force",  force = "player", mode = "and"},
    {filter = "name", name = "constructron-rocket-powered", mode = "or"},
    {filter = "force",  force = "player", mode = "and"},
    {filter = "name", name = "service_station", mode = "or"},
    {filter = "force",  force = "player", mode = "and"},
    {filter = "name", name = "entity-ghost", mode = "or"},
    {filter = "force",  force = "player", mode = "and"},
    {filter = "name", name = "tile-ghost", mode = "or"},
    {filter = "force",  force = "player", mode = "and"},
    {filter = "name", name = "item-request-proxy", mode = "or"},
    {filter = "force",  force = "player", mode = "and"}
})

script.on_event(ev.script_raised_built, entity_proc.on_built_entity, {
    {filter = "name", name = "constructron", mode = "or"},
    {filter = "name", name = "constructron-rocket-powered", mode = "or"},
    {filter = "name", name = "service_station", mode = "or"},
    {filter = "name", name = "entity-ghost", mode = "or"},
    {filter = "name", name = "tile-ghost", mode = "or"},
    {filter = "name", name = "item-request-proxy", mode = "or"}
})

script.on_event(ev.on_robot_built_entity, entity_proc.on_built_entity, {
    {filter = "name", name = "service_station", mode = "or"}
})

-- for entities that die and need rebuilding
script.on_event(ev.on_post_entity_died, function(event)
    local entity = event.ghost
    if entity and entity.valid and global.rebuild_job_toggle[entity.surface.index] and (entity.type == 'entity-ghost') and (entity.force.name == "player") then
        global.construction_index = global.construction_index + 1
        global.construction_entities[global.construction_index] = entity
        global.construction_tick = event.tick
        global.entity_proc_trigger = true -- there is something to do start processing
    end
end)

-- for entity deconstruction
script.on_event(ev.on_marked_for_deconstruction, function(event)
    local entity = event.entity
    if not global.deconstruction_job_toggle[entity.surface.index] or not entity then return end
    global.deconstruction_index = global.deconstruction_index + 1
    global.entity_proc_trigger = true -- there is something to do start processing
    local force_name = entity.force.name
    if force_name == "player" or force_name == "neutral" then
        global.deconstruction_tick = event.tick
        global.deconstruction_entities[global.deconstruction_index] = entity
    end
end, {{filter = "type", type = "fish", invert = true, mode = "or"}})

-- for entity upgrade
script.on_event(ev.on_marked_for_upgrade, function(event)
    local entity = event.entity
    if not global.upgrade_job_toggle[entity.surface.index] or not entity or not entity.force.name == "player" then return end
    global.upgrade_index = global.upgrade_index + 1
    global.upgrade_tick = event.tick
    global.upgrade_entities[global.upgrade_index] = entity
    global.entity_proc_trigger = true -- there is something to do start processing
end)

-- for entity repair
script.on_event(ev.on_entity_damaged, function(event)
    local entity = event.entity
    if not global.repair_job_toggle[entity.surface.index] then return end
    local force = entity.force.name
    local entity_pos = entity.position
    local key = entity.surface.index .. ',' .. entity_pos.x .. ',' .. entity_pos.y
    if (force == "player") then
        if not global.repair_entities[key] then
            global.repair_tick = event.tick
            global.repair_entities[key] = entity
            global.entity_proc_trigger = true -- there is something to do start processing
        end
    elseif force == "player" and global.repair_entities[key] and event.final_health == 0 then
        global.repair_entities[key] = nil
    end
end,
{
    {filter = "final-health", comparison = ">", value = 0, mode = "and"},
    {filter = "robot-with-logistics-interface", invert = true, mode = "and"},
    {filter = "vehicle", invert = true, mode = "and"},
    {filter = "rolling-stock", invert = true, mode = "and"},
    {filter = "type", type = "character", invert = true, mode = "and"},
    {filter = "type", type = "fish", invert = true, mode = "and"}
})

script.on_event(ev.on_entity_cloned, function(event)
    local entity = event.destination
    local surface_index = entity.surface.index
    if entity.name == 'constructron' or entity.name == "constructron-rocket-powered" then
        local registration_number = script.register_on_entity_destroyed(entity)
        util_func.paint_constructron(entity, 'idle')
        global.constructrons[entity.unit_number] = entity
        global.registered_entities[registration_number] = {
            name = "constructron",
            surface = surface_index
        }
        global.constructrons_count[surface_index] = global.constructrons_count[surface_index] + 1
        global.available_ctron_count[surface_index] = global.available_ctron_count[surface_index] + 1
        -- combinator related
        global.constructron_requests[entity.unit_number] = {}
        global.constructron_requests[entity.unit_number].requests = {}
        for _, station in pairs(global.service_stations) do
            util_func.update_combinator(station, "constructron_pathing_proxy_1", 0)
        end
        -- utility
        if (global.stations_count[surface_index] > 0) then
            global.managed_surfaces[surface_index] = entity.surface.name
        end
        entity.vehicle_automatic_targeting_parameters = {
            auto_target_without_gunner = true,
            auto_target_with_gunner = true
        }
    elseif entity.name == "service_station" then
        local registration_number = script.register_on_entity_destroyed(entity)
        global.service_stations[entity.unit_number] = entity
        global.registered_entities[registration_number] = {
            name = "service_station",
            surface = surface_index
        }
        global.stations_count[surface_index] = global.stations_count[surface_index] + 1
        -- configure surface management
        if (global.constructrons_count[surface_index] > 0) then
            global.managed_surfaces[surface_index] = entity.surface.name
        end
        -- combinator setup
        local control_behavior = entity.get_or_create_control_behavior()
        control_behavior.read_logistics = false
        local combinator = entity.surface.create_entity{
            name = "ctron-combinator",
            position = {(entity.position.x + 1), (entity.position.y + 1)},
            direction = defines.direction.west,
            force = entity.force,
            raise_built = true
        } ---@cast combinator -nil
        local circuit1 = { wire = defines.wire_type.red, target_entity = entity }
        local circuit2 = { wire = defines.wire_type.green, target_entity = entity }
        combinator.connect_neighbour(circuit1)
        combinator.connect_neighbour(circuit2)
        local signals = {
            [1] = {index = 1, signal = {type = "virtual", name = "signal-C"}, count = global.constructrons_count[entity.surface.index]},
            [2] = {index = 2, signal = {type = "virtual", name = "signal-A"}, count = global.available_ctron_count[entity.surface.index]}
        }
        global.station_combinators[entity.unit_number] = {entity = combinator, signals = {}}
        combinator.get_control_behavior().parameters = signals
        global.station_requests[entity.unit_number] = {}
    end
end,
{
    {filter = "name", name = "constructron", mode = "or"},
    {filter = "name", name = "constructron-rocket-powered", mode = "or"},
    {filter = "name", name = "service_station", mode = "or"},
})

script.on_event(ev.script_raised_teleported, function(event)
    local entity = event.entity
    local surface_index = entity.surface_index
    if not (surface_index == event.old_surface_index) then return end
    if entity.name == 'constructron' or entity.name == "constructron-rocket-powered" then
        util_func.paint_constructron(entity, 'idle')
        util_func.set_constructron_status(entity, 'busy', false)
        global.constructrons_count[event.old_surface_index] = global.constructrons_count[event.old_surface_index] - 1
        global.constructrons_count[entity.surface_index] = global.constructrons_count[entity.surface_index] + 1
        if global.constructron_statuses[entity.unit_number] and not global.constructron_statuses[entity.unit_number]["busy"] then
            global.available_ctron_count[event.old_surface_index] = global.available_ctron_count[event.old_surface_index] - 1
        end
        global.available_ctron_count[entity.surface_index] = global.available_ctron_count[entity.surface_index] + 1
        for _, job in pairs(global.jobs) do
            if (job.worker.unit_number == entity.unit_number) then
                -- remove worker from job
                job.worker = nil
            end
        end
        -- configure surface management
        if (global.stations_count[entity.surface_index] > 0) then
            global.managed_surfaces[surface_index] = entity.surface.name
        end
    elseif entity.name == "service_station" then
        global.stations_count[event.old_surface_index] = global.stations_count[event.old_surface_index] - 1
        global.stations_count[entity.surface_index] = global.stations_count[event.old_surface_index] + 1
        -- configure surface management
        if (global.constructrons_count[entity.surface_index] > 0) then
            global.managed_surfaces[surface_index] = entity.surface.name
        end
    end
end,
{
    {filter = "name", name = "constructron", mode = "or"},
    {filter = "name", name = "constructron-rocket-powered", mode = "or"},
    {filter = "name", name = "service_station", mode = "or"}
})

---@param event
---| EventData.on_entity_destroyed
---| EventData.script_raised_destroy
entity_proc.on_entity_destroyed = function(event)
    if not global.registered_entities[event.registration_number] then return end
    local removed_entity = global.registered_entities[event.registration_number]
    local surface_index = removed_entity.surface
    if removed_entity.name == "constructron" or removed_entity.name == "constructron-rocket-powered" then
        if game.surfaces[surface_index] then
            global.constructrons_count[surface_index] = global.constructrons_count[surface_index] - 1
            if global.constructron_statuses[event.unit_number] and not global.constructron_statuses[event.unit_number]["busy"] then
                global.available_ctron_count[surface_index] = global.available_ctron_count[surface_index] - 1
            end
        end
        global.constructrons[event.unit_number] = nil
        global.constructron_statuses[event.unit_number] = nil
        -- surface management
        if (global.stations_count[surface_index] or 0) <= 0 then
            global.managed_surfaces[surface_index] = nil
        end
        -- combinator management
        global.constructron_requests[event.unit_number] = nil
        for _, station in pairs(global.service_stations) do
            util_func.update_combinator(station, "constructron_pathing_proxy_1", 0)
        end
    elseif removed_entity.name == "service_station" then
        if game.surfaces[surface_index] then
            global.stations_count[surface_index] = global.stations_count[surface_index] - 1
        end
        global.service_stations[event.unit_number] = nil
        -- surface management
        if (global.constructrons_count[surface_index] or 0) <= 0 then
            global.managed_surfaces[surface_index] = nil
        end
        -- combinator management
        global.station_combinators[event.unit_number].entity.destroy{raise_destroy = true}
        global.station_combinators[event.unit_number] = nil
        global.station_requests[event.unit_number] = nil
    end
    global.registered_entities[event.registration_number] = nil
end

script.on_event(ev.on_entity_destroyed, entity_proc.on_entity_destroyed)

script.on_event(ev.script_raised_destroy, entity_proc.on_entity_destroyed, {
    {filter = "name", name = "constructron", mode = "or"},
    {filter = "name", name = "constructron-rocket-powered", mode = "or"},
    {filter = "name", name = "service_station", mode = "or"}
})

script.on_event(ev.on_sector_scanned, function(event)
    local surface = event.radar.surface
    if not global.destroy_job_toggle[surface.index] then return end
    local enemies = surface.find_entities_filtered({
        force = {"enemy"},
        area = event.area,
        is_military_target = true,
        type = {"unit-spawner", "turret"}
    })
    if not next(enemies) then return end
    local enemies_list = {}
    for _, enemy in pairs(enemies) do
        if not enemies_list[enemy.unit_number] then
            enemies_list[enemy.unit_number] = enemy
            enemies_list = entity_proc.recursive_enemy_search(enemy, enemies_list)
        end
    end
    for _, entity in pairs(enemies_list) do
        global.destroy_index = global.destroy_index + 1
        global.destroy_entities[global.destroy_index] = entity
        global.destroy_tick = event.tick
        global.entity_proc_trigger = true
    end
end)

-- left click
script.on_event(ev.on_player_selected_area, function(event)
    if event.item ~= "ctron-selection-tool" then return end
    for _, entity in pairs(event.entities) do
        if entity and entity.valid then
            if entity.type == 'entity-ghost' or entity.type == 'tile-ghost' or entity.type == 'item-request-proxy' then
                global.construction_index = global.construction_index + 1
                global.construction_entities[global.construction_index] = entity
                global.construction_tick = event.tick
                global.entity_proc_trigger = true -- there is something to do start processing
            end
        end
    end
end)

-- right click
script.on_event(ev.on_player_reverse_selected_area, function(event)
    if event.item ~= "ctron-selection-tool" then return end
    for _, entity in pairs(event.entities) do
        if entity and entity.valid then
            local force_name = entity.force.name
            if force_name == "player" or force_name == "neutral" then
                entity.order_deconstruction(game.players[event.player_index].force, game.players[event.player_index])
                global.deconstruction_tick = event.tick
                global.deconstruction_entities[global.deconstruction_index] = entity
                global.deconstruction_index = global.deconstruction_index + 1
                global.entity_proc_trigger = true -- there is something to do start processing
            end
        end
    end
end)

-- shift right click
script.on_event(ev.on_player_alt_reverse_selected_area, function(event)
    if event.item ~= "ctron-selection-tool" then return end
    for _, entity in pairs(event.entities) do
        if entity and entity.valid then
            if entity.force.name == "enemy" then
                global.destroy_index = global.destroy_index + 1
                global.destroy_entities[global.destroy_index] = entity
                global.destroy_tick = event.tick
                global.entity_proc_trigger = true  -- there is something to do start processing
            end
        end
    end
end)

-------------------------------------------------------------------------------
--  Entity processing
-------------------------------------------------------------------------------

---@param build_type string
---@param entities table
---@param queue EntityQueue
entity_proc.add_entities_to_chunks = function(build_type, entities, queue) -- build_type: deconstruction, construction, upgrade, repair, destroy
    if next(entities) then
        local entity_counter = global.entities_per_second
        for entity_key, entity in pairs(entities) do
            if entity.valid then
                local registered
                if build_type == "destroy" then
                    registered = true
                elseif build_type == "deconstruction" then
                    registered = entity.is_registered_for_deconstruction(game.forces.player)
                else
                    registered = entity["is_registered_for_" .. build_type]()
                end
                if registered then -- check if robots are not already performing the job
                    local required_items = {}
                    local trash_items = {}
                    local entity_type = entity.type
                    local entity_surface = entity.surface.index
                    -- construction
                    if (build_type == "construction") then
                        if not (entity_type == 'item-request-proxy') then
                            local items_to_place_cache = global.items_to_place_cache[entity.ghost_name]
                            required_items[items_to_place_cache.item] = (required_items[items_to_place_cache.item] or 0) + items_to_place_cache.count
                        end
                        -- module requests
                        if not (entity_type == "tile-ghost") then
                            for name, count in pairs(entity.item_requests) do
                                required_items[name] = (required_items[name] or 0) + count
                            end
                        end
                    -- deconstruction
                    elseif (build_type == "deconstruction") then
                        if (entity_type == "cliff") then -- cliff demolition
                            required_items['cliff-explosives'] = (required_items['cliff-explosives'] or 0) + 1
                        else
                            local entity_name = entity.name
                            if (global.entity_inventory_cache[entity_name] == nil) then -- if entity is not in cache
                                -- build entity inventory cache
                                global.entity_inventory_cache[entity_name] = {}
                                local max_index = 0 -- TODO: https://lua-api.factorio.com/latest/classes/LuaControl.html#get_max_inventory_index
                                for _, index in pairs(defines.inventory) do -- get maximum index value of defines.inventory
                                    if index > max_index then
                                        max_index = index
                                    end
                                end
                                for i = 1, max_index do
                                    local inventory = entity.get_inventory(i)
                                    if (inventory ~= nil) then
                                        table.insert(global.entity_inventory_cache[entity_name], i) -- add inventory defines index to cache against the entity
                                    end
                                end
                                if not next(global.entity_inventory_cache[entity_name]) then
                                    global.entity_inventory_cache[entity_name] = false -- item does not have an inventory
                                end
                            end
                            if (global.entity_inventory_cache[entity_name] ~= false) then -- if entity is in the cache and has an inventory
                                -- check inventory contents
                                for _, inventory_id in pairs(global.entity_inventory_cache[entity_name]) do
                                    local inventory = entity.get_inventory(inventory_id)
                                    if (inventory ~= nil) then
                                        local inv_contents = inventory.get_contents()
                                        if (inv_contents ~= nil) then
                                            for item, count in pairs(inv_contents) do
                                                trash_items[item] = (trash_items[item] or 0) + count
                                            end
                                        end
                                    end
                                end
                                -- add the entity itself to the trash_items
                                if global.trash_items_cache[entity_name] then
                                    for product_name, count in pairs(global.trash_items_cache[entity_name]) do
                                        trash_items[product_name] = (trash_items[product_name] or 0) + count
                                    end
                                else
                                    debug_lib.DebugLog('Constructron:-Continued: Entity not cached! please report this to mod author!' .. entity_name .. '')
                                end
                            elseif not (entity_name == "item-on-ground") then
                                if not (entity_name == "deconstructible-tile-proxy") then
                                    for product_name, count in pairs(global.trash_items_cache[entity_name]) do
                                        trash_items[product_name] = (trash_items[product_name] or 0) + count
                                    end
                                else
                                    trash_items["concrete"] = (trash_items["concrete"] or 0) + 1 -- assuming tile name because there doesn't seem to be a way to get what will be picked up
                                end
                            else
                                local entity_stack = entity.stack
                                trash_items[entity_stack.name] = (trash_items[entity_stack.name] or 0) + entity_stack.count
                            end
                        end
                    -- upgrade
                    elseif build_type == "upgrade" then
                        local target_entity = entity.get_upgrade_target()
                        local items_to_place_cache = global.items_to_place_cache[target_entity.name]
                        required_items[items_to_place_cache.item] = (required_items[items_to_place_cache.item] or 0) + items_to_place_cache.count
                    -- repair
                    elseif (build_type == "repair") then
                        required_items[global.repair_tool_name[entity_surface]] = (required_items[global.repair_tool_name[entity_surface]] or 0) + 1
                    -- destroy
                    elseif (build_type == "destroy") then
                        -- repair packs are hard coded to robot count * 4
                    end
                    -- entity chunking
                    local entity_pos = entity.position
                    local entity_pos_y = entity_pos.y
                    local entity_pos_x = entity_pos.x
                    local chunk = {
                        y = (math.floor((entity_pos_y) / 80)),
                        x = (math.floor((entity_pos_x) / 80))
                    }
                    local key = chunk.y .. ',' .. chunk.x
                    -- local queue_surface_key = queue[entity_surface][chunk.y][chunk.x] -- TODO: Optimization candidate
                    local queue_surface_key = queue[entity_surface][key]
                    if not queue_surface_key then -- initialize a new chunk
                        queue_surface_key = {
                            key = key,
                            last_update_tick = game.tick,
                            surface = entity_surface,
                            area = util_func.get_area_from_chunk(chunk),
                            minimum = {
                                x = entity_pos_x,
                                y = entity_pos_y
                            },
                            maximum = {
                                x = entity_pos_x,
                                y = entity_pos_y
                            },
                            required_items = required_items or {},
                            trash_items = trash_items or {}
                        }
                    else -- add to existing queued chunk
                        if entity_pos_x < queue_surface_key['minimum'].x then
                            queue_surface_key['minimum'].x = entity_pos_x -- expand chunk area
                        elseif entity_pos_x > queue_surface_key['maximum'].x then
                            queue_surface_key['maximum'].x = entity_pos_x -- expand chunk area
                        end
                        if entity_pos_y < queue_surface_key['minimum'].y then
                            queue_surface_key['minimum'].y = entity_pos_y -- expand chunk area
                        elseif entity_pos_y > queue_surface_key['maximum'].y then
                            queue_surface_key['maximum'].y = entity_pos_y -- expand chunk area
                        end
                        for item, count in pairs(required_items) do
                            queue_surface_key['required_items'][item] = (queue_surface_key['required_items'][item] or 0) + count
                        end
                        for item, count in pairs(trash_items) do
                            queue_surface_key['trash_items'][item] = (queue_surface_key['trash_items'][item] or 0) + count
                        end
                        queue_surface_key.last_update_tick = game.tick
                    end
                    queue[entity_surface][key] = queue_surface_key -- update global chunk queue
                end
            end
            entities[entity_key] = nil -- clear entity from entity queue
            entity_counter = entity_counter - 1
            if entity_counter <= 0 then
                if global.debug_toggle then
                    for index, _ in pairs(queue) do
                        for _, chunk in pairs(queue[index]) do
                            debug_lib.draw_rectangle(chunk.minimum, chunk.maximum, chunk.surface, "red", false, 15)
                        end
                    end
                end
                return
            end
        end
    end
end

-------------------------------------------------------------------------------
--  Utility functions
-------------------------------------------------------------------------------

-- function to recursively search for other biter nests around a nest
---@param enemy LuaEntity
---@param enemies_list table<uint32, LuaEntity>
---@return table<uint32, LuaEntity>
entity_proc.recursive_enemy_search = function(enemy, enemies_list)
    local enemy_pos = enemy.position
    local search = enemy.surface.find_entities_filtered({
        force = {"enemy"},
        area = {
            left_top = {
                x = enemy_pos.x - 5,
                y = enemy_pos.y - 5
            },
            right_bottom = {
                x = enemy_pos.x + 5,
                y = enemy_pos.y + 5
            }
        },
        is_military_target = true,
        type = {"unit-spawner", "turret"}
    })
    for _, entity in pairs(search) do
        if not enemies_list[entity.unit_number] then
            enemies_list[entity.unit_number] = entity
            enemies_list = entity_proc.recursive_enemy_search(entity, enemies_list)
        end
    end
    return enemies_list
end

return entity_proc
