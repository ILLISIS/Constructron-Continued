local util_func = require("script/utility_functions")
local debug_lib = require("script/debug_lib")
local gui_job = require("script/ui_job_screen")

local entity_proc = {}

--- Processes entity positions into chunks
---@param entity LuaEntity|LuaTile
---@param queue table
---@param entity_surface_index uint
---@param from_tool boolean?
entity_proc.create_chunk = function(entity, queue, entity_surface_index, from_tool)
    local entity_pos = entity.position
    local entity_pos_x = entity_pos.x
    local entity_pos_y = entity_pos.y
    local chunkx = math.floor(entity_pos_x / 80) -- dividing by 80 as that is the size of 4 roboports
    local chunky = math.floor(entity_pos_y / 80) -- dividing by 80 as that is the size of 4 roboports
    local key = (chunkx + 12500) * 25000 + (chunky + 12500) -- add 12500 to make sure the key is always positive
    local chunk = queue[key]
    if not chunk then -- initialize a new chunk
        chunk = {
            key = key,
            surface_index = entity_surface_index,
            last_update_tick = game.tick,
            minimum = {
                x = entity_pos_x,
                y = entity_pos_y
            },
            maximum = {
                x = entity_pos_x,
                y = entity_pos_y
            },
            from_tool = from_tool or false
        }
    else -- update existing queued chunk
        if entity_pos_x < chunk['minimum'].x then
            chunk['minimum'].x = entity_pos_x -- expand minimum chunk area x axis
        elseif entity_pos_x > chunk['maximum'].x then
            chunk['maximum'].x = entity_pos_x -- expand maximum chunk area x axis
        end
        if entity_pos_y < chunk['minimum'].y then
            chunk['minimum'].y = entity_pos_y -- expand minimum chunk area y axis
        elseif entity_pos_y > chunk['maximum'].y then
            chunk['maximum'].y = entity_pos_y -- expand maximum chunk area y axis
        end
        chunk.last_update_tick = game.tick
        chunk.from_tool = from_tool or false -- deconstruction from tool raises the event which creates a chunk
    end
    queue[key] = chunk
end

-------------------------------------------------------------------------------
--  Event handlers
-------------------------------------------------------------------------------
local ev = defines.events

-- this method is used when a new constructron is built
---@param entity LuaEntity
---@param surface_index uint
entity_proc.new_ctron_built = function(entity, surface_index)
    local registration_number = script.register_on_object_destroyed(entity)
    storage.registered_entities[registration_number] = {
        name = entity.name,
        surface = surface_index
    }
    util_func.paint_constructron(entity, 'idle')
    entity.enable_logistics_while_moving = false
    storage.constructrons[entity.unit_number] = entity
    storage.constructron_statuses[entity.unit_number] = { busy = false }
    storage.constructrons_count[surface_index] = storage.constructrons_count[surface_index] + 1
    storage.available_ctron_count[surface_index] = storage.available_ctron_count[surface_index] + 1
    util_func.update_ctron_combinator_signals(surface_index)
    -- utility
    if (storage.stations_count[surface_index] > 0) then
        storage.managed_surfaces[surface_index] = entity.surface.name
    end
    entity.vehicle_automatic_targeting_parameters = {
        auto_target_without_gunner = true,
        auto_target_with_gunner = true
    }
end

-- this method is used when a new service station is built
---@param entity LuaEntity
---@param surface_index uint
entity_proc.new_station_built = function(entity, surface_index)
    local registration_number = script.register_on_object_destroyed(entity)
    storage.service_stations[entity.unit_number] = entity
    storage.registered_entities[registration_number] = {
        name = entity.name,
        surface = surface_index
    }
    storage.stations_count[surface_index] = storage.stations_count[surface_index] + 1
    if (storage.constructrons_count[surface_index] > 0) then
        storage.managed_surfaces[surface_index] = entity.surface.name
    end
    -- combinator setup
    local control_behavior = entity.get_or_create_control_behavior() --[[@as LuaRoboportControlBehavior]]
    control_behavior.read_logistics = false
    local combinator = storage.ctron_combinators[surface_index]
    if not (combinator and combinator.valid) then
        storage.ctron_combinators[surface_index] = util_func.setup_station_combinator(entity)
    else
        util_func.connect_station_to_combinator(combinator, entity)
    end
    -- cargo jobs
    storage.station_requests[entity.unit_number] = {}
end

local entity_types = {
    ["entity-ghost"] = true,
    ["tile-ghost"] = true,
    ["item-request-proxy"] = true
}

-- for entity creation
---@param event
---| EventData.on_built_entity
---| EventData.on_robot_built_entity
---| EventData.script_raised_built
entity_proc.on_built_entity = function(event)
    local entity = event.entity
    local surface_index = entity.surface.index
    if storage.construction_job_toggle[surface_index] and entity_types[entity.type] then
        entity_proc.create_chunk(entity, storage.construction_queue[surface_index], surface_index)
    elseif storage.constructron_names[entity.name] then -- register constructron
        entity_proc.new_ctron_built(entity, surface_index)
    elseif storage.station_names[entity.name] then -- register service station
        entity_proc.new_station_built(entity, surface_index)
    end
end

script.on_event(ev.on_built_entity, entity_proc.on_built_entity, {
    {filter = "type", type = "spider-vehicle", mode = "or"},
    {filter = "force",  force = "player", mode = "and"},
    {filter = "type", type = "roboport", mode = "or"},
    {filter = "force",  force = "player", mode = "and"},
    {filter = "name", name = "entity-ghost", mode = "or"},
    {filter = "force",  force = "player", mode = "and"},
    {filter = "name", name = "tile-ghost", mode = "or"},
    {filter = "force",  force = "player", mode = "and"},
    {filter = "name", name = "item-request-proxy", mode = "or"},
    {filter = "force",  force = "player", mode = "and"}
})

script.on_event(ev.script_raised_built, entity_proc.on_built_entity, {
    {filter = "type", type = "spider-vehicle", mode = "or"},
    {filter = "type", type = "roboport", mode = "or"},
    {filter = "name", name = "entity-ghost", mode = "or"},
    {filter = "name", name = "tile-ghost", mode = "or"},
    {filter = "name", name = "item-request-proxy", mode = "or"}
})

script.on_event(ev.on_robot_built_entity, entity_proc.on_built_entity, {
    {filter = "type", type = "spider-vehicle", mode = "or"},
    {filter = "type", type = "roboport", mode = "or"},
})

-- for entities that die and need rebuilding
script.on_event(ev.on_post_entity_died, function(event)
    local ghost_entity = event.ghost ---@cast ghost_entity -nil
    if not (ghost_entity and ghost_entity.valid) then return end
    if not ghost_entity.force.name == "player" then return end
    local surface_index = ghost_entity.surface.index
    if storage.rebuild_job_toggle[surface_index] and (ghost_entity.type == 'entity-ghost') then
        entity_proc.create_chunk(ghost_entity, storage.construction_queue[surface_index], surface_index)
    end
end)

-- for entity deconstruction
script.on_event(ev.on_marked_for_deconstruction, function(event)
    local entity = event.entity
    local surface_index = entity.surface.index
    if not storage.deconstruction_job_toggle[surface_index] or not entity then return end
    entity_proc.create_chunk(entity, storage.deconstruction_queue[surface_index], surface_index)
end, {{filter = "type", type = "fish", invert = true, mode = "or"}})

-- for entity upgrade
script.on_event(ev.on_marked_for_upgrade, function(event)
    local entity = event.entity
    local surface_index = entity.surface.index
    if not storage.upgrade_job_toggle[surface_index] or not entity or not entity.force.name == "player" then return end
    entity_proc.create_chunk(entity, storage.upgrade_queue[surface_index], surface_index)
end)

-- for entity repair
script.on_event(ev.on_entity_damaged, function(event)
    local entity = event.entity
    local surface_index = entity.surface.index
    if not storage.repair_job_toggle[surface_index] then return end
    if entity.force.name ~= "player" then return end
    entity_proc.create_chunk(entity, storage.repair_queue[surface_index], surface_index)
end,
{
    {filter = "name", name = "captive-biter-spawner", invert = true, mode = "and"},
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
    if storage.constructron_names[entity.name] then
        local registration_number = script.register_on_object_destroyed(entity)
        util_func.paint_constructron(entity, 'idle')
        storage.constructrons[entity.unit_number] = entity
        storage.registered_entities[registration_number] = {
            name = entity.name,
            surface = surface_index
        }
        storage.constructron_statuses[entity.unit_number] = { busy = false }
        storage.constructrons_count[surface_index] = storage.constructrons_count[surface_index] + 1 -- update constructron count
        storage.available_ctron_count[surface_index] = storage.available_ctron_count[surface_index] + 1 -- update available constructron count
        util_func.update_ctron_combinator_signals(surface_index)
        -- utility
        if (storage.stations_count[surface_index] > 0) then
            storage.managed_surfaces[surface_index] = entity.surface.name
        end
        entity.vehicle_automatic_targeting_parameters = {
            auto_target_without_gunner = true,
            auto_target_with_gunner = true
        }
    elseif storage.station_names[entity.name] then
        local registration_number = script.register_on_object_destroyed(entity)
        storage.service_stations[entity.unit_number] = entity
        storage.registered_entities[registration_number] = {
            name = entity.name,
            surface = surface_index
        }
        storage.stations_count[surface_index] = storage.stations_count[surface_index] + 1
        -- configure surface management
        if (storage.constructrons_count[surface_index] > 0) then
            storage.managed_surfaces[surface_index] = entity.surface.name
        end
        -- cargo jobs
        storage.station_requests[entity.unit_number] = {}
    elseif entity.name == "ctron-combinator" then
        entity.destroy{raise_destroy = true}
    end
end,
{
    {filter = "type", type = "spider-vehicle", mode = "or"},
    {filter = "type", type = "roboport", mode = "or"},
    {filter = "name", name = "ctron-combinator", mode = "or"}
})

script.on_event(ev.script_raised_teleported, function(event)
    local entity = event.entity
    local surface_index = entity.surface_index
    if not (surface_index == event.old_surface_index) then return end
    if storage.constructron_names[entity.name] then
        util_func.paint_constructron(entity, 'idle')
        storage.constructrons_count[event.old_surface_index] = math.max((storage.constructrons_count[event.old_surface_index] - 1), 0) -- update constructron count on old surface
        storage.constructrons_count[entity.surface_index] = storage.constructrons_count[entity.surface_index] + 1 -- update constructron count on new surface
        if not storage.constructron_statuses[entity.unit_number]["busy"] then -- if constructron is not busy
            storage.available_ctron_count[event.old_surface_index] = math.max((storage.available_ctron_count[event.old_surface_index] - 1), 0) -- update available constructron count on old surface
        end
        storage.constructron_statuses[entity.unit_number] = { busy = false } -- set constructron status
        storage.available_ctron_count[entity.surface_index] = storage.available_ctron_count[entity.surface_index] + 1 -- update available constructron count on new surface
        util_func.update_ctron_combinator_signals(entity.surface_index)
        for _, job in pairs(storage.jobs) do
            if (job.worker.unit_number == entity.unit_number) then
                -- remove worker from job
                job.worker = nil
            end
        end
        -- configure surface management
        if (storage.stations_count[entity.surface_index] > 0) then
            storage.managed_surfaces[surface_index] = entity.surface.name
        end
    elseif storage.station_names[entity.name] then
        storage.stations_count[event.old_surface_index] = storage.stations_count[event.old_surface_index] - 1
        storage.stations_count[entity.surface_index] = storage.stations_count[event.old_surface_index] + 1
        -- configure surface management
        if (storage.constructrons_count[entity.surface_index] > 0) then
            storage.managed_surfaces[surface_index] = entity.surface.name
        end
    elseif entity.name == "ctron-combinator" then
        entity.destroy{raise_destroy = true}
    end
end,
{
    {filter = "type", type = "spider-vehicle", mode = "or"},
    {filter = "type", type = "roboport", mode = "or"},
    {filter = "name", name = "ctron-combinator", mode = "or"}
})

---@param event
---| EventData.on_object_destroyed
---| EventData.script_raised_destroy
entity_proc.on_object_destroyed = function(event)
    if not storage.registered_entities[event.registration_number] then return end
    local removed_entity = storage.registered_entities[event.registration_number]
    local surface_index = removed_entity.surface
    if storage.constructron_names[removed_entity.name] then
        if game.surfaces[surface_index] then
            storage.constructrons_count[surface_index] = math.max((storage.constructrons_count[surface_index] - 1), 0) -- update constructron count
            if not storage.constructron_statuses[event.useful_id]["busy"] then -- if constructron is not busy
                storage.available_ctron_count[surface_index] = math.max((storage.available_ctron_count[surface_index] - 1), 0) -- update available constructron count
            end
        end
        util_func.update_ctron_combinator_signals(surface_index)
        storage.constructrons[event.useful_id] = nil
        storage.constructron_statuses[event.useful_id] = nil
        -- surface management
        if (storage.stations_count[surface_index] or 0) <= 0 then
            storage.managed_surfaces[surface_index] = nil
        end
        -- combinator management
        util_func.update_ctron_combinator_signals(removed_entity.surface)
    elseif storage.station_names[removed_entity.name] then
        if game.surfaces[surface_index] then
            storage.stations_count[surface_index] = storage.stations_count[surface_index] - 1
        end
        storage.service_stations[event.useful_id] = nil
        -- surface management
        if (storage.constructrons_count[surface_index] or 0) <= 0 then
            storage.managed_surfaces[surface_index] = nil
        end
        -- cargo requests
        storage.station_requests[event.useful_id] = nil
    elseif removed_entity.name == "ctron-combinator" then
        if storage.stations_count[surface_index] > 0 then
            local _, new_station = next(util_func.get_service_stations(surface_index))
            if not new_station then return end
            util_func.setup_station_combinator(new_station)
        end
    end
    storage.registered_entities[event.registration_number] = nil
end

script.on_event(ev.on_object_destroyed, entity_proc.on_object_destroyed)

script.on_event(ev.script_raised_destroy, entity_proc.on_object_destroyed, {
    {filter = "type", type = "spider-vehicle", mode = "or"},
    {filter = "type", type = "roboport", mode = "or"},
    {filter = "name", name = "ctron-combinator", mode = "or"}
})

script.on_event(ev.on_sector_scanned, function(event)
    local surface = event.radar.surface
    if not storage.destroy_job_toggle[surface.index] then return end
    local entity_surface_index = surface.index
    local entities = game.surfaces[entity_surface_index].find_entities_filtered{
        area = event.area,
        force = "enemy",
        type = { "unit-spawner", "turret" },
    }
    if not next(entities) then return end
    for _, entity in pairs(entities) do
        entity_proc.create_chunk(entity, storage.destroy_queue[entity_surface_index], entity_surface_index)
    end
end)

-- left click
script.on_event(ev.on_player_selected_area, function(event)
    if event.item ~= "ctron-selection-tool" then return end
    local surface_index = event.surface.index
    for _, entity in pairs(event.entities) do
        if entity and entity.valid then
            if entity.type == 'entity-ghost' or entity.type == 'tile-ghost' or entity.type == 'item-request-proxy' then
                entity_proc.create_chunk(entity, storage.construction_queue[surface_index], surface_index, true)
            end
        end
    end
    for _, entity in pairs(event.surface.find_entities_filtered{area=event.area, type='item-request-proxy'}) do
        entity_proc.create_chunk(entity, storage.construction_queue[surface_index], surface_index, true)
    end
end)

-- right click
script.on_event(ev.on_player_reverse_selected_area, function(event)
    if event.item ~= "ctron-selection-tool" then return end
    for _, entity in pairs(event.entities) do
        if entity and entity.valid then
            local force_name = entity.force.name
            if force_name == "player" or force_name == "neutral" then
                local entity_surface_index = entity.surface.index
                local player = game.players[event.player_index]
                entity_proc.create_chunk(entity, storage.deconstruction_queue[entity_surface_index], entity_surface_index, true)
                entity.order_deconstruction(player.force, player)
            end
        end
    end
    for _, tile in pairs(event.tiles) do
        local tile_surface_index = tile.surface.index
        local player = game.players[event.player_index]
        tile.order_deconstruction(player.force, player)
        entity_proc.create_chunk(tile, storage.deconstruction_queue[tile_surface_index], tile_surface_index, true)
    end
end)

-- shift left click
script.on_event(ev.on_player_alt_selected_area, function (event)
    if event.item ~= "ctron-selection-tool" then return end
    local player = game.players[event.player_index]
    for _, entity in pairs(event.entities) do
        if entity and entity.valid and entity.name == "constructron" then
            for _, job in pairs(storage.jobs) do
                if job.worker.unit_number == entity.unit_number then
                    if not player.gui.screen.ctron_job_window then
                        gui_job.buildJobGui(player, job)
                        player.opened = player.gui.screen.ctron_job_window
                    else
                        player.gui.screen.ctron_job_window.destroy()
                        gui_job.buildJobGui(player, job)
                        player.opened = player.gui.screen.ctron_job_window
                    end
                    break
                end
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
                local entity_surface_index = entity.surface_index
                entity_proc.create_chunk(entity, storage.destroy_queue[entity_surface_index], entity_surface_index, true)
            end
        end
    end
end)

-------------------------------------------------------------------------------
--  Entity processing
-------------------------------------------------------------------------------

---@param entity LuaEntity
entity_proc.deconstruction = function(entity)
    if not entity.is_registered_for_deconstruction(game.forces.player) then return end
    local required_items = {}
    local trash_items = {}
    local entity_type = entity.type
    local quality_level = entity.quality.name
    if (entity_type == "cliff") then -- cliff demolition
        required_items['cliff-explosives'] = {}
        required_items['cliff-explosives']["normal"] = (required_items['cliff-explosives']["normal"] or 0) + 1
        return required_items, trash_items
    end
    local entity_name = entity.name
    if (storage.entity_inventory_cache[entity_name] == nil) then -- if entity is not in cache
        -- build entity inventory cache
        storage.entity_inventory_cache[entity_name] = {}
        local max_index = entity.get_max_inventory_index()
        for i = 1, max_index do
            local inventory = entity.get_inventory(i)
            if (inventory ~= nil) then
                table.insert(storage.entity_inventory_cache[entity_name], i) -- add inventory defines index to cache against the entity
            end
        end
        if not next(storage.entity_inventory_cache[entity_name]) then
            storage.entity_inventory_cache[entity_name] = false -- item does not have an inventory
        end
    end
    if (storage.entity_inventory_cache[entity_name] ~= false) then -- if entity is in the cache and has an inventory
        -- check inventory contents
        for _, inventory_id in pairs(storage.entity_inventory_cache[entity_name]) do
            local inventory = entity.get_inventory(inventory_id)
            if (inventory ~= nil) then
                local inv_contents = inventory.get_contents()
                if (inv_contents ~= nil) then
                    for _, item in pairs(inv_contents) do
                        local item_name = item.name
                        local quality_level = item.quality
                        trash_items[item_name] = trash_items[item_name] or {}
                        trash_items[item_name][quality_level] = (trash_items[item_name][quality_level] or 0) + item.count
                    end
                end
            end
        end
        -- add the entity itself to the trash_items
        if storage.trash_items_cache[entity_name] then
            for product_name, count in pairs(storage.trash_items_cache[entity_name]) do
                trash_items[product_name] = trash_items[product_name] or {}
                trash_items[product_name][quality_level] = (trash_items[product_name][quality_level] or 0) + count
            end
        else
            debug_lib.DebugLog('Constructron:-Continued: Entity not cached! please report this to mod author!' .. entity_name .. '')
        end
    elseif not (entity_name == "item-on-ground") then
        if not (entity_name == "deconstructible-tile-proxy") then
            for product_name, count in pairs(storage.trash_items_cache[entity_name]) do
                trash_items[product_name] = trash_items[product_name] or {}
                trash_items[product_name][quality_level] = (trash_items[product_name][quality_level] or 0) + count
            end
        else
            -- deconstructible-tile-proxy
            trash_items["concrete"] = trash_items["concrete"] or {}
            trash_items["concrete"]["normal"] = (trash_items["concrete"]["normal"] or 0) + 1 -- assuming tile name because there doesn't seem to be a way to get what will be picked up
        end
    else
        -- item-on-ground
        local entity_stack = entity.stack
        local quality_level = entity.quality.name
        trash_items[entity_stack.name] = trash_items[entity_stack.name] or {}
        trash_items[entity_stack.name][quality_level] = (trash_items[entity_stack.name][quality_level] or 0) + entity_stack.count
    end
    return required_items, trash_items
end

local construction_entity_types = {
    ["entity-ghost"] = function(entity)
        local required_items = {}
        local trash_items = {}
        local items_to_place_cache = storage.items_to_place_cache[entity.ghost_name]
        local quality_level = entity.quality.name
        local item = items_to_place_cache.item
        required_items[item] = required_items[item] or {}
        required_items[item][quality_level] = (required_items[item][quality_level] or 0) + items_to_place_cache.count
        -- item requests / modules
        for _, item_request in pairs(entity.item_requests) do
            local item_name = item_request.name
            local quality_level = item_request.quality
            required_items[item_name] = required_items[item_name] or {}
            required_items[item_name][quality_level] = (required_items[item_name][quality_level] or 0) + item_request.count
        end
        return required_items, trash_items
    end,
    ["tile-ghost"] = function(entity)
        local required_items = {}
        local trash_items = {}
        local items_to_place_cache = storage.items_to_place_cache[entity.ghost_name]
        local quality_level = entity.quality.name
        local item = items_to_place_cache.item
        required_items[item] = required_items[item] or {}
        required_items[item][quality_level] = (required_items[item][quality_level] or 0) + items_to_place_cache.count
        return required_items, trash_items
    end,
    ["item-request-proxy"] = function(entity)
        local required_items = {}
        local trash_items = {}
        for _, item in pairs(entity.item_requests) do
            local item_name = item.name
            local quality_level = item.quality
            required_items[item_name] = required_items[item_name] or {}
            required_items[item_name][quality_level] = (required_items[item_name][quality_level] or 0) + item.count
        end
        return required_items, trash_items
    end
}

---@param entity LuaEntity
entity_proc.construction = function(entity)
    if not entity.is_registered_for_construction() then return end
    local entity_type = entity.type
    local required_items, trash_items = construction_entity_types[entity_type](entity)
    return required_items, trash_items
end

---@param entity LuaEntity
entity_proc.upgrade = function(entity)
    if not entity.is_registered_for_upgrade() then return end
    local required_items = {}
    local trash_items = {}
    local target_entity, quality = entity.get_upgrade_target()
    ---@cast target_entity -nil
    ---@cast quality -nil
    local target_quality_level = quality.name
    local current_quality_level = entity.quality.name
    local items_to_place_cache = storage.items_to_place_cache[target_entity.name]
    local item_name = items_to_place_cache.item
    required_items[item_name] = required_items[item_name] or {}
    required_items[item_name][target_quality_level] = (required_items[item_name][target_quality_level] or 0) + items_to_place_cache.count
    trash_items[item_name] = trash_items[item_name] or {}
    trash_items[item_name][current_quality_level] = (trash_items[item_name][current_quality_level] or 0) + 1
    return required_items, trash_items
end

---@param entity LuaEntity
entity_proc.repair = function(entity)
    if not entity.is_registered_for_repair() then return end
    local required_items = {}
    local trash_items = {}
    local repair_tool = storage.repair_tool_name[entity.surface.index]
    local repair_tool_name = repair_tool.name
    local quality_level = repair_tool.quality
    required_items[repair_tool_name] = required_items[repair_tool_name] or {}
    required_items[repair_tool_name][quality_level] = (required_items[repair_tool_name][quality_level] or 0) + 1
    return required_items, trash_items
end

---@param entity LuaEntity
entity_proc.destroy = function(entity)
    local required_items = {}
    local trash_items = {}
    return required_items, trash_items
end

-------------------------------------------------------------------------------
--  Utility functions
-------------------------------------------------------------------------------

-- function to recursively search for other biter nests around a nest
---@param enemy LuaEntity
---@param enemies_list table<uint32, LuaEntity>
---@return table<uint32, LuaEntity>
entity_proc.recursive_enemy_search = function(enemy, enemies_list, chunk)
    local enemy_pos = enemy.position
    local search = enemy.surface.find_entities_filtered({
        force = {"enemy"},
        area = {
            left_top = {
                x = enemy_pos.x - 8,
                y = enemy_pos.y - 8
            },
            right_bottom = {
                x = enemy_pos.x + 8,
                y = enemy_pos.y + 8
            }
        },
        type = {"unit-spawner", "turret"}
    })
    for _, entity in pairs(search) do
        if not enemies_list[entity.unit_number] then
            -- check if the entity is in the same chunk
            local entity_pos = entity.position
            local entity_pos_x = entity_pos.x
            local entity_pos_y = entity_pos.y
            local chunkx = math.floor(entity_pos_x / 80) -- dividing by 80 as that is the size of 4 roboports
            local chunky = math.floor(entity_pos_y / 80) -- dividing by 80 as that is the size of 4 roboports
            local key = (chunkx + 12500) * 25000 + (chunky + 12500) -- add 12500 to make sure the key is always positive
            if chunk.key ~= key and storage.destroy_queue[entity.surface_index][key] then
                -- remove chunk from queue (merge the chunk)
                storage.destroy_queue[entity.surface_index][key] = nil
            end
            -- update chunk area
            if entity_pos_x < chunk['minimum'].x then
                chunk['minimum'].x = entity_pos_x -- expand minimum chunk area x axis
            elseif entity_pos_x > chunk['maximum'].x then
                chunk['maximum'].x = entity_pos_x -- expand maximum chunk area x axis
            end
            if entity_pos_y < chunk['minimum'].y then
                chunk['minimum'].y = entity_pos_y -- expand minimum chunk area y axis
            elseif entity_pos_y > chunk['maximum'].y then
                chunk['maximum'].y = entity_pos_y -- expand maximum chunk area y axis
            end
            enemies_list[entity.unit_number] = entity
            enemies_list = entity_proc.recursive_enemy_search(entity, enemies_list, chunk)
        end
    end
    return enemies_list
end

return entity_proc
