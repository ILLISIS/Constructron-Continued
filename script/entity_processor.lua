local ctron = require("script/constructron")
local chunk_util = require("script/chunk_util")
local debug_lib = require("script/debug_lib")

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
    if not global.construction_job_toggle then return end
    local entity = event.created_entity or event.entity
    local entity_type = entity.type
    if entity_type == 'entity-ghost' or entity_type == 'tile-ghost' or entity_type == 'item-request-proxy' then
        global.construction_index = global.construction_index + 1
        global.construction_entities[global.construction_index] = entity
        global.construction_tick = event.tick
        global.entity_proc_trigger = true -- there is something to do start processing
    elseif entity.name == 'constructron' or entity.name == "constructron-rocket-powered" then -- register constructron
        local registration_number = script.register_on_entity_destroyed(entity)
        local surface_index = entity.surface.index
        ctron.set_constructron_status(entity, 'busy', false)
        ctron.paint_constructron(entity, 'idle')
        entity.enable_logistics_while_moving = false
        global.constructrons[entity.unit_number] = entity
        global.registered_entities[registration_number] = {
            name = "constructron",
            surface = surface_index
        }
        global.constructrons_count[surface_index] = global.constructrons_count[surface_index] + 1
        global.available_ctron_count[surface_index] = global.available_ctron_count[surface_index] + 1
        if (global.stations_count[surface_index] > 0) then
            global.managed_surfaces[entity.surface.name] = surface_index
        end
    elseif entity.name == "service_station" then -- register service station
        local registration_number = script.register_on_entity_destroyed(entity)
        local surface_index = entity.surface.index
        global.service_stations[entity.unit_number] = entity
        global.registered_entities[registration_number] = {
            name = "service_station",
            surface = surface_index
        }
        global.stations_count[surface_index] = global.stations_count[surface_index] + 1
        if (global.constructrons_count[surface_index] > 0) then
            global.managed_surfaces[entity.surface.name] = surface_index
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
        }
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
    end
end

---@param event EventData.on_built_entity
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

---@param event EventData.script_raised_built
script.on_event(ev.script_raised_built, entity_proc.on_built_entity, {
    {filter = "name", name = "constructron", mode = "or"},
    {filter = "name", name = "constructron-rocket-powered", mode = "or"},
    {filter = "name", name = "service_station", mode = "or"},
    {filter = "name", name = "entity-ghost", mode = "or"},
    {filter = "name", name = "tile-ghost", mode = "or"},
    {filter = "name", name = "item-request-proxy", mode = "or"}
})

---@param event EventData.on_robot_built_entity
script.on_event(ev.on_robot_built_entity, entity_proc.on_built_entity, {
    {filter = "name", name = "service_station", mode = "or"}
})

-- for entities that die and need rebuilding
---@param event EventData.on_post_entity_died
script.on_event(ev.on_post_entity_died, function(event)
    if not global.rebuild_job_toggle then return end
    local entity = event.ghost
    if entity and entity.valid and (entity.type == 'entity-ghost') and (entity.force.name == "player") then
        global.construction_index = global.construction_index + 1
        global.construction_entities[global.construction_index] = entity
        global.construction_tick = event.tick
        global.entity_proc_trigger = true -- there is something to do start processing
    end
end)

-- for entity deconstruction
---@param event EventData.on_marked_for_deconstruction
script.on_event(ev.on_marked_for_deconstruction, function(event)
    if not global.deconstruction_job_toggle then return end
    local entity = event.entity
    global.deconstruction_index = global.deconstruction_index + 1
    global.entity_proc_trigger = true -- there is something to do start processing
    local force_name = entity.force.name
    if force_name == "player" or force_name == "neutral" then
        global.deconstruction_tick = event.tick
        global.deconstruction_entities[global.deconstruction_index] = entity
    end
end, {{filter = "type", type = "fish", invert = true, mode = "or"}})

-- for entity upgrade
---@param event EventData.on_marked_for_upgrade
script.on_event(ev.on_marked_for_upgrade, function(event)
    if not global.upgrade_job_toggle then return end
    local entity = event.entity
    if entity.force.name == "player" then
        global.upgrade_index = global.upgrade_index + 1
        global.upgrade_tick = event.tick
        global.upgrade_entities[global.upgrade_index] = entity
        global.entity_proc_trigger = true -- there is something to do start processing
    end
end)

-- for entity repair
---@param event EventData.on_entity_damaged
script.on_event(ev.on_entity_damaged, function(event)
    if not global.repair_job_toggle then return end
    local entity = event.entity
    local force = entity.force.name
    local entity_pos = entity.position
    local key = entity.surface.index .. ',' .. entity_pos.x .. ',' .. entity_pos.y
    if (force == "player") and (((event.final_health / entity.prototype.max_health) * 100) <= settings.global["repair_percent"].value) then
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

---@param event EventData.on_entity_cloned
script.on_event(ev.on_entity_cloned, function(event)
    local entity = event.destination
    local surface_index = entity.surface.index
    if entity.name == 'constructron' or entity.name == "constructron-rocket-powered" then
        local registration_number = script.register_on_entity_destroyed(entity)
        ctron.paint_constructron(entity, 'idle')
        global.constructrons[entity.unit_number] = entity
        global.registered_entities[registration_number] = {
            name = "constructron",
            surface = surface_index
        }
        global.constructrons_count[surface_index] = global.constructrons_count[surface_index] + 1
        global.available_ctron_count[surface_index] = global.available_ctron_count[surface_index] + 1
        -- configure surface management
        if (global.stations_count[surface_index] > 0) then
            global.managed_surfaces[entity.surface.name] = surface_index
        end
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
            global.managed_surfaces[entity.surface.name] = surface_index
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
        }
        local circuit1 = { wire = defines.wire_type.red, target_entity = entity }
        local circuit2 = { wire = defines.wire_type.green, target_entity = entity }
        combinator.connect_neighbour(circuit1)
        combinator.connect_neighbour(circuit2)
        local signals = {
            [1] = {index = 1, signal = {type = "virtual", name = "signal-C"}, count = global.constructrons_count[entity.surface.index]},
            [2] = {index = 2, signal = {type = "virtual", name = "signal-A"}, count = global.available_ctron_count}
        }
        global.station_combinators[entity.unit_number] = {entity = combinator, signals = {}}
        combinator.get_control_behavior().parameters = signals
    end
end,
{
    {filter = "name", name = "constructron", mode = "or"},
    {filter = "name", name = "constructron-rocket-powered", mode = "or"},
    {filter = "name", name = "service_station", mode = "or"},
})

---@param event EventData.script_raised_teleported
script.on_event(ev.script_raised_teleported, function(event)
    local entity = event.entity
    local surface_index = entity.surface_index
    if not (surface_index == event.old_surface_index) then
        if entity.name == 'constructron' or entity.name == "constructron-rocket-powered" then
            ctron.paint_constructron(entity, 'idle')
            ctron.set_constructron_status(entity, 'busy', false)
            global.constructrons_count[event.old_surface_index] = global.constructrons_count[event.old_surface_index] - 1
            global.constructrons_count[entity.surface_index] = global.constructrons_count[entity.surface_index] + 1
            global.available_ctron_count[event.old_surface_index] = global.available_ctron_count[event.old_surface_index] - 1
            global.available_ctron_count[entity.surface_index] = global.available_ctron_count[entity.surface_index] + 1
            for _, job in pairs(global.jobs) do
                if (job.worker.unit_number == entity.unit_number) then
                    -- remove worker from job
                    job.worker = nil
                end
            end
            -- configure surface management
            if (global.stations_count[entity.surface_index] > 0) then
                global.managed_surfaces[entity.surface.name] = surface_index
            end
        elseif entity.name == "service_station" then
            global.stations_count[event.old_surface_index] = global.stations_count[event.old_surface_index] - 1
            global.stations_count[entity.surface_index] = global.stations_count[event.old_surface_index] + 1
            -- configure surface management
            if (global.constructrons_count[entity.surface_index] > 0) then
                global.managed_surfaces[entity.surface.name] = surface_index
            end
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
    if global.registered_entities[event.registration_number] then
        local removed_entity = global.registered_entities[event.registration_number]
        local surface_index = removed_entity.surface
        local surface_name = game.surfaces[surface_index].name
        if removed_entity.name == "constructron" or removed_entity.name == "constructron-rocket-powered" then
            global.constructrons_count[surface_index] = global.constructrons_count[surface_index] - 1
            global.available_ctron_count[surface_index] = global.available_ctron_count[surface_index] - 1
            global.constructrons[event.unit_number] = nil
            global.constructron_statuses[event.unit_number] = nil
            -- configure surface management
            if (global.stations_count[surface_index] <= 0) then
                global.managed_surfaces[surface_name] = nil
            end
        elseif removed_entity.name == "service_station" then
            global.stations_count[surface_index] = global.stations_count[surface_index] - 1
            global.service_stations[event.unit_number] = nil
            -- configure surface management
            if (global.constructrons_count[surface_index] <= 0) then
                global.managed_surfaces[surface_name] = nil
            end
            global.station_combinators[event.unit_number].entity.destroy{raise_destroy = true}
            global.station_combinators[event.unit_number] = nil
        end
        global.registered_entities[event.registration_number] = nil
    end
end

script.on_event(ev.on_entity_destroyed, entity_proc.on_entity_destroyed)

script.on_event(ev.script_raised_destroy, entity_proc.on_entity_destroyed, {
    {filter = "name", name = "constructron", mode = "or"},
    {filter = "name", name = "constructron-rocket-powered", mode = "or"},
    {filter = "name", name = "service_station", mode = "or"}
})

---@param event EventData.on_sector_scanned
script.on_event(ev.on_sector_scanned, function(event)
    if not global.destroy_job_toggle then return end
    local surface = event.radar.surface
    local enemies = surface.find_entities_filtered({
        force = {"enemy"},
        area = event.area
    })
    if next(enemies) then
        for _, entity in pairs(enemies) do
            global.destroy_index = global.destroy_index + 1
            global.destroy_entities[global.destroy_index] = entity
            global.destroy_tick = event.tick
            global.entity_proc_trigger = true
        end
    end
end)

---@param event EventData.on_player_selected_area
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

---@param event EventData.on_player_reverse_selected_area
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

---@param event EventData.on_player_alt_selected_area
script.on_event(ev.on_player_alt_selected_area, function(event)
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

---@param build_type BuildType
---@param entities table
---@param queue EntityQueue
---@param event_tick integer
entity_proc.add_entities_to_chunks = function(build_type, entities, queue, event_tick) -- build_type: deconstruction, construction, upgrade, repair, destroy
    if next(entities) and (game.tick - event_tick) > global.job_start_delay then -- if the entity isn't processed in 5 seconds or 300 ticks(default setting).
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
                                local max_index = 0
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
                        required_items['repair-pack'] = (required_items['repair-pack'] or 0) + 3
                    -- destroy
                    elseif (build_type == "destroy") then
                        required_items['repair-pack'] = (required_items['repair-pack'] or 0) + 3
                    end
                    -- entity chunking
                    local entity_surface = entity.surface.index
                    local entity_pos = entity.position
                    local entity_pos_y = entity_pos.y
                    local entity_pos_x = entity_pos.x
                    local chunk = {
                        y = (math.floor((entity_pos_y) / 80)),
                        x = (math.floor((entity_pos_x) / 80))
                    }
                    local key = chunk.y .. ',' .. chunk.x
                    local queue_surface_key = queue[entity_surface][key]
                    if not queue_surface_key then -- initialize a new chunk
                        queue_surface_key = {
                            key = key,
                            surface = entity_surface,
                            -- position = chunk_util.position_from_chunk(chunk), -- !! check if needed
                            area = chunk_util.get_area_from_chunk(chunk),
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

return entity_proc