local ctron = require("script/constructron")
local chunk_util = require("script/chunk_util")

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
        global.ghost_index = global.ghost_index + 1
        global.ghost_entities[global.ghost_index] = entity
        global.ghost_tick = event.tick
    elseif entity.name == 'constructron' or entity.name == "constructron-rocket-powered" then -- register constructron
        local registration_number = script.register_on_entity_destroyed(entity)
        ctron.set_constructron_status(entity, 'busy', false)
        ctron.paint_constructron(entity, 'idle')
        entity.enable_logistics_while_moving = false
        global.constructrons[entity.unit_number] = entity
        global.registered_entities[registration_number] = {
            name = "constructron",
            surface = entity.surface.index
        }
        global.constructrons_count[entity.surface.index] = global.constructrons_count[entity.surface.index] + 1
    elseif entity.name == "service_station" then -- register service station
        local registration_number = script.register_on_entity_destroyed(entity)
        global.service_stations[entity.unit_number] = entity
        global.registered_entities[registration_number] = {
            name = "service_station",
            surface = entity.surface.index
        }
        global.stations_count[entity.surface.index] = global.stations_count[entity.surface.index] + 1
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
    if not global.rebuild_job_toggle then return end
    local entity = event.ghost

    if entity and entity.valid and (entity.type == 'entity-ghost') and (entity.force.name == "player") then
        global.ghost_index = global.ghost_index + 1
        global.ghost_entities[global.ghost_index] = entity
        global.ghost_tick = event.tick
    end
end)

-- for entity deconstruction
script.on_event(ev.on_marked_for_deconstruction, function(event)
    if not global.deconstruction_job_toggle then return end
    local entity = event.entity
    global.decon_index = global.decon_index + 1
    if not (entity.name == "item-on-ground") then
        local force_name = entity.force.name
        if force_name == "player" or force_name == "neutral" then
            global.deconstruct_marked_tick = event.tick
            global.deconstruction_entities[global.decon_index] = entity
        end
    elseif global.ground_decon_job_toggle then
        local force_name = entity.force.name
        if force_name == "player" or force_name == "neutral" then
            global.deconstruct_marked_tick = event.tick
            global.deconstruction_entities[global.decon_index] = entity
        end
    end
end)

-- for entity upgrade
script.on_event(ev.on_marked_for_upgrade, function(event)
    if not global.upgrade_job_toggle then return end
    local entity = event.entity
    if entity.force.name == "player" then
        global.upgrade_index = global.upgrade_index + 1
        global.upgrade_marked_tick = event.tick
        global.upgrade_entities[global.upgrade_index] = entity
    end
end)

-- for entity repair
script.on_event(ev.on_entity_damaged, function(event)
    if not global.repair_job_toggle then return end
    local entity = event.entity
    local force = entity.force.name
    local entity_pos = entity.position
    local key = entity.surface.index .. ',' .. entity_pos.x .. ',' .. entity_pos.y
    if (force == "player") and (((event.final_health / entity.prototype.max_health) * 100) <= settings.global["repair_percent"].value) then
        if not global.repair_entities[key] then
            global.repair_marked_tick = event.tick
            global.repair_entities[key] = entity
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

-------------------------------------------------------------------------------
--  Entity processing
-------------------------------------------------------------------------------

---@param build_type BuildType
---@param entities table
---@param queue EntityQueue
---@param event_tick integer
entity_proc.add_entities_to_chunks = function(build_type, entities, queue, event_tick) -- build_type: deconstruction, construction, upgrade, repair
    if next(entities) and (game.tick - event_tick) > global.job_start_delay then -- if the entity isn't processed in 5 seconds or 300 ticks(default setting).
        local entity_counter = global.entities_per_tick
        for entity_key, entity in pairs(entities) do
            if entity.valid then
                local registered
                if build_type == "deconstruction" then
                    registered = entity.is_registered_for_deconstruction(game.forces.player)
                else
                    registered = entity["is_registered_for_" .. build_type]()
                end
                if registered then -- check if robots are not already performing the job
                    local required_items = {}
                    local trash_items = {}
                    -- construction
                    if (build_type == "construction") then
                        local entity_type = entity.type
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
                        if not (entity.type == "cliff") then
                            for _, item in ipairs(entity.prototype.mineable_properties.products) do
                                local amount = item.amount or item.amount_max
                                trash_items[item.name] = (trash_items[item.name] or 0) + amount
                            end
                        else -- cliff demolition
                            required_items['cliff-explosives'] = (required_items['cliff-explosives'] or 0) + 1
                        end
                    -- upgrade
                    elseif build_type == "upgrade" then
                        local target_entity = entity.get_upgrade_target()
                        local items_to_place_cache = global.items_to_place_cache[target_entity.name]
                        required_items[items_to_place_cache.item] = (required_items[items_to_place_cache.item] or 0) + items_to_place_cache.count
                    -- repair
                    elseif (build_type == "repair") then
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
            if entity_counter <= 0 then break end
        end
    end
end

-------------------------------------------------------------------------------
--  Utility
-------------------------------------------------------------------------------

return entity_proc