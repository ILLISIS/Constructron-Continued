require("util")
local collision_mask_util_extended = require("script.collision-mask-util-control")

local function table_has_value (tab, val)
    if val == nil then
        return false
    end
    if not tab then
        return false
    end
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

local function DebugLog(message)
    if settings.global["constructron-debug-enabled"].value then
        game.print(message)
        log(message)
    end
end

local function VisualDebugText(message, entity)
    if not entity or not entity.valid then
        return
    end
	if settings.global["constructron-debug-enabled"].value then
        rendering.draw_text {
            text = message,
            target = entity,
            filled = true,
            surface = entity.surface,
            time_to_live = 60,
            target_offset = {0, -2},
            alignment = "center",
            color = {
                r = 255,
                g = 255,
                b = 255,
                a = 255
            }
        }
    end
end

local function VisualDebugCircle(position, surface, color, text)
	if settings.global["constructron-debug-enabled"].value then
        if position then
            rendering.draw_circle {
                target = position,
                radius = 0.5,
                filled = true,
                surface = surface,
                time_to_live = 900,
                color = color
            }
            if text then
                rendering.draw_text {
                    text = text,
                    target = position,
                    filled = true,
                    surface = surface,
                    time_to_live = 900,
                    target_offset = {0, 0},
                    alignment = "center",
                    color = {
                        r = 255,
                        g = 255,
                        b = 255,
                        a = 255
                    }
                }
            end
        end
    end
end

max_jobtime = (settings.global["max-jobtime-per-job"].value * 60 * 60)
job_start_delay = (settings.global["job-start-delay"].value * 60)

function get_service_stations(index)
    local stations_on_surface = {}
    for s, station in pairs(global.service_stations) do
        if (index == station.surface.index) then
            table.insert(stations_on_surface, station.unit_number, station)
        end
    end
    return stations_on_surface or {}
end

function get_constructrons()
    local constructrons_on_surface
    for c, constructron in pairs(global.constructrons) do
        table.insert(constructrons_on_surface, constructron)
    end
    return constructrons_on_surface or {}
end

function distance_between(position1, position2)
    return math.sqrt(math.pow(position1.x - position2.x, 2) + math.pow(position1.y - position2.y, 2))
end

function constructrons_need_reload(constructrons)
    for c, constructron in ipairs(constructrons) do
        if not constructron.valid then return end
        local trunk_inventory = constructron.get_inventory(defines.inventory.spider_trunk)
        local trunk = {}
        for i = 1, #trunk_inventory do
            local item = trunk_inventory[i]
            if item.valid_for_read then
                trunk[item.name] = (trunk[item.name] or 0) + item.count
            end
        end
        for i = 1, constructron.request_slot_count do
            local request = constructron.get_vehicle_logistic_slot(i)
            if request then
                if not (((trunk[request.name] or 0) >= request.min) and
                    ((trunk[request.name] or 0) <= request.max)) then
                        return true
                end
            end
        end
    end
    return false
end

function calculate_required_inventory_slot_count(required_items, divisor)
    local slots = 0
    for name, count in pairs(required_items) do
        local stack_size = game.item_prototypes[name].stack_size
        slots = slots + math.ceil(count / stack_size / divisor)
    end
    return slots
end

script.on_init(function()
    global.constructron_pathfinder_requests = {}
    global.ignored_entities = {}
    global.ghost_entities = {}
    global.ghost_entities_count = 0
    global.deconstruction_entities = {}
    global.deconstruction_entities_count = 0
    global.upgrade_entities = {}
    global.constructron_statuses = {}
    global.construct_queue = {}  
    global.deconstruct_queue = {}
    global.upgrade_queue = {}
    global.job_bundles = {}
    global.constructrons = {}
    global.service_stations = {}
    global.registered_entities = {}
    global.constructrons_count = {}
    global.stations_count = {}
end)

script.on_configuration_changed(function()
    global.constructron_pathfinder_requests = global.constructron_pathfinder_requests or {}
    global.constructron_statuses = global.constructron_statuses or {}
    global.deconstruction_entities = global.deconstruction_entities or {}
    global.deconstruction_entities_count = global.deconstruction_entities_count or 0
    global.upgrade_entities = global.upgrade_entities or {}
    global.construct_queue = global.construct_queue or {}
    global.deconstruct_queue = global.deconstruct_queue or {}
    global.upgrade_queue = global.upgrade_queue or {}
    global.ignored_entities = global.ignored_entities or {}
    global.ghost_entities = global.ghost_entities or {}
    global.ghost_entities_count = global.ghost_entities_count or 0
    global.job_bundles = global.job_bundles or {}
    global.constructrons = global.constructrons or {}
    global.service_stations = global.service_stations or {}
    global.registered_entities = global.registered_entities or {}
    global.constructrons_count = global.constructrons_count or {}
    global.stations_count = global.stations_count or {}
end)

function request_path(constructrons, goal)
    local constructron = constructrons[1]
    if constructron.valid then
        local surface = constructron.surface
        local new_start = surface.find_non_colliding_position("constructron_pathing_dummy", constructron.position, 32, 0.1, false)
        local new_goal = surface.find_non_colliding_position("constructron_pathing_dummy", goal, 32, 0.1, false)
        VisualDebugCircle(goal,surface,{r = 100, g = 0, b = 0, a = 0.2})
        VisualDebugCircle(new_goal,surface,{r = 0, g = 100, b = 0, a = 0.2})
        if new_goal and new_start then
            local pathing_collision_mask = {
                "water-tile",
                --"consider-tile-transitions", 
                "colliding-with-tiles-only"
            }
            if game.active_mods["space-exploration"] then
                local spaceship_collision_layer = collision_mask_util_extended.get_named_collision_mask("moving-tile")
                local empty_space_collision_layer = collision_mask_util_extended.get_named_collision_mask("empty-space-tile")
                table.insert(pathing_collision_mask, spaceship_collision_layer)
                table.insert(pathing_collision_mask, empty_space_collision_layer)
            end
            local request_id = surface.request_path {
                bounding_box = {{-3, -3}, {3, 3}},
                collision_mask = pathing_collision_mask,
                start = new_start,
                goal = new_goal,
                force = constructron.force,
                pathfinding_flags = {
                    cache = false,
                    low_priority = true
                }
            }
            global.constructron_pathfinder_requests[request_id] = {
                constructrons = constructrons
            }
            for c, constructron in ipairs(constructrons) do
                constructron.autopilot_destination = nil
            end
            return new_goal
        else
            VisualDebugText("pathfinding request failed - target not reachable", constructron)
        end
    else
        invalid = true
        return invalid
    end
end

script.on_event(defines.events.on_script_path_request_finished, function(event)
    local request = global.constructron_pathfinder_requests[event.id]
    if not (request == nil) then
        local constructrons = request.constructrons
        local clean_path
        if event.path then
            clean_path = clean_linear_path(event.path)
        end
        for c, constructron in ipairs(constructrons) do
            constructron.autopilot_destination = nil
            if event.path then
                local i = 0
                for i, waypoint in ipairs(clean_path) do
                    constructron.add_autopilot_destination(waypoint.position)
                    VisualDebugCircle(waypoint.position,constructron.surface,{r = 100, g = 0, b = 100, a = 0.2},tostring(i))
                    i = i + 1
                end
            else
				VisualDebugText("pathfinder callback path nil", constructron)
			end
        end
	else
		VisualDebugText("pathfinder callback request nil", constructrons[1])
	end
    global.constructron_pathfinder_requests[event.id] = nil
end)

function clean_linear_path(path)
    -- removes points on the same line except the start and the end.
    local new_path = {}
    for i, waypoint in ipairs(path) do
        if i >= 2 and i < #path then
            local prev_angle = math.atan2(waypoint.position.y - path[i - 1].position.y,
                waypoint.position.x - path[i - 1].position.x)
            local next_angle = math.atan2(path[i + 1].position.y - waypoint.position.y,
                path[i + 1].position.x - waypoint.position.x)
            if math.abs(prev_angle - next_angle) > 0.01 then
                table.insert(new_path, waypoint)
            end
        else
            table.insert(new_path, waypoint)
        end
    end
    return new_path
end

function chunk_from_position(position)
    -- if a ghost entity found anywhere in the surface, we want to get the corresponding chunk
    -- so that we can fill constructron with all the other ghosts
    return {
        y = math.floor((position.y) / 80),
        x = math.floor((position.x) / 80)
    }
end

function position_from_chunk(chunk)
    return {
        y = chunk.y * 80,
        x = chunk.x * 80
    }
end

function get_area_from_chunk(chunk)
    local area = {{
        y = chunk.y * 80,-- - 6,
        x = chunk.x * 80-- - 6
    }, {
        y = (chunk.y+1) * 80,-- + 6,
        x = (chunk.x+1) * 80-- + 6
    }}
    -- rendering.draw_rectangle {
    --     left_top = area[1],
    --     right_bottom = area[2],
    --     filled = true,
    --     surface = game.surfaces['nauvis'],
    --     time_to_live = 5000,
    --     color = {
    --         r = 100,
    --         g = 100,
    --         b = 100,
    --         a = 0.2
    --     }
    -- }
    return area
end

-- This section is unused.
-- function find_ghosts(chunk, position, radius)
--     -- both chunk and position are optional
--     -- if given chunk, it will look in that chunk
--     -- if given position, it will find the corresponding chunk and look in that chunk
--     -- if not given any of it, it will find a single ghost
--     local area = nil
--     if chunk then
--         area = get_area_from_chunk(chunk)
--     elseif position then
--         return game.surfaces['nauvis'].find_entities_filtered {
--             position = position,
--             radius = radius,
--             type = "entity-ghost"
--         }
--     else
--         return game.surfaces['nauvis'].find_entities_filtered {
--             type = "entity-ghost",
--             limit = 1
--         }
--     end
--     local ghosts = game.surfaces['nauvis'].find_entities_filtered {
--         type = "entity-ghost",
--         area = area
--     }
--     return ghosts
-- end

entity_per_tick = 100

function merge_direct_neighbour(a1, a2)

    local merge
    -- if they are in the same row
    if (a1[1].y == a2[1].y) and (a1[2].y == a2[2].y) then
        -- if they are neighbours
        if (a1[1].x == a2[2].x) or (a1[2].x == a2[1].x) then
            merge = true
        end
    end

    -- if they are in the same column
    if (a1[1].x == a2[1].x) and (a1[2].x == a2[2].x) then
        -- if they are neighbours
        if (a1[1].y == a2[2].y) or (a1[2].y == a2[1].y) then
            merge = true
        end
    end
    if merge then
        return {{
            x = math.min(a1[1].x, a2[1].x),
            y = math.min(a1[1].y, a2[1].y)
        }, {
            x = math.max(a1[2].x, a2[2].x),
            y = math.max(a1[2].y, a2[2].y)
        }}
    end
end

function merge_neighbour_chunks(merged_area, chunk1, chunk2)
    -- must be called if chunks are direct neighbors. area is what is returned from merge_direct_neighbour function.
    local new_chunk = {
        area = merged_area,
        minimum = chunk1.minimum,
        maximum = chunk1.maximum,
        position = {
            x = math.min(chunk1.minimum.x, chunk2.minimum.x),
            y = math.min(chunk1.minimum.y, chunk2.minimum.y)
        }
    }
    local required_items = {}
    for key, count in pairs(chunk1.required_items) do
        required_items[key] = count
    end
    for key, count in pairs(chunk2.required_items) do
        required_items[key] = (required_items[key] or 0) + count
    end
    for xy, val in pairs(chunk2.minimum) do
        new_chunk.minimum[xy] = math.min(val, new_chunk.minimum[xy])
    end
    for xy, val in pairs(chunk2.maximum) do
        new_chunk.maximum[xy] = math.max(val, new_chunk.maximum[xy])
    end
    new_chunk['required_items'] = required_items
    return new_chunk
end

function combine_chunks(chunks)
    for i, chunk1 in ipairs(chunks) do
        for j, chunk2 in ipairs(chunks) do
            if not (i == j) then
                local merged_area = merge_direct_neighbour(chunk1.area, chunk2.area)
                if merged_area then
                    local new_chunk = merge_neighbour_chunks(merged_area, chunk1, chunk2)
                    local new_chunks = {}
                    for k, chunk in ipairs(chunks) do
                        if (not (k == i)) and (not (k == j)) then
                            table.insert(new_chunks, chunk)
                        end
                    end
                    table.insert(new_chunks, new_chunk)
                    return combine_chunks(new_chunks) -- recursion
                end
            end
        end
    end
    return chunks
end

function calculate_construct_positions(area, radius)
    local height = math.max(area[2].y - area[1].y, 1) -- a single object has no width or height. which makes xpoint_count and ypoint_count zero. which means it won't be build.
    local width = math.max(area[2].x - area[1].x, 1) -- so, if either height or width are zero. they must be set to at least 1.
    local xpoints = {}
    local ypoints = {}
    local xpoint_count = math.ceil(width / radius / 2)
    local ypoint_count = math.ceil(height / radius / 2)

    if xpoint_count > 1 then
        for i = 1, xpoint_count do
            xpoints[i] = area[1].x + radius + (width - radius * 2) * (i - 1) / (xpoint_count - 1)
        end
    else
        xpoints[1] = area[1].x + width / 2
    end

    if ypoint_count > 1 then
        for j = 1, ypoint_count do
            ypoints[j] = area[1].y + radius + (height - radius * 2) * (j - 1) / (ypoint_count - 1)
        end
    else
        ypoints[1] = area[1].y + height / 2
    end

    local points = {}
    if xpoint_count < ypoint_count then
        for x = 1, xpoint_count do
            for y = 1, ypoint_count do
                table.insert(points, {
                    x = xpoints[x],
                    y = ypoints[(ypoint_count + 1) * (x % 2) + math.pow(-1, x % 2) * y]
                })
            end
        end
    else
        for y = 1, ypoint_count do
            for x = 1, xpoint_count do
                table.insert(points, {
                    y = ypoints[y],
                    x = xpoints[(xpoint_count + 1) * (y % 2) + math.pow(-1, y % 2) * x]
                })
            end
        end
    end
    if settings.global["constructron-debug-enabled"].value then
        for p, point in pairs(points) do
            local otherp = {}
            otherp.x = point.x - 1
            otherp.y = point.y - 1
            rendering.draw_rectangle {
                left_top = point,
                right_bottom = otherp,
                filled = true,
                surface = game.surfaces['nauvis'],
                time_to_live = 1800,
                color = {
                    r = 100,
                    g = 100,
                    b = 100,
                    a = 0.2
                }
            }
        end
    end
    return points
end

-- idea
-- local entity_per_tick = #entities
-- if entity_per_tick > 100 then
--     entity_per_tick = 100
-- end

function add_ghosts_to_chunks()
    if global.ghost_entities[1] and (game.tick - global.ghost_tick) > job_start_delay then -- if the ghost isn't built in 5 seconds or 300 ticks(default setting).
        for i = 1, entity_per_tick do
            -- local entity = table.remove(global.ghost_entities)
            local ghost_count = global.ghost_entities_count
            local entity = global.ghost_entities[ghost_count]
            if ghost_count > 0 then
                global.ghost_entities[ghost_count] = nil
                global.ghost_entities_count = ghost_count - 1
                if entity.valid then
                    local chunk = chunk_from_position(entity.position)
                    local key = chunk.y .. ',' .. chunk.x
                    local chunk_surface = entity.surface.index
                    local entity_key = entity.position.y .. ',' .. entity.position.x
                    global.construct_queue[chunk_surface] = global.construct_queue[chunk_surface] or {}
                    if not global.construct_queue[chunk_surface][key] then -- initialize queued_chunk
                        global.construct_queue[chunk_surface][key] = {
                            key = key,
                            surface = entity.surface.index,
                            entity_key = entity,
                            position = position_from_chunk(chunk),
                            area = get_area_from_chunk(chunk),
                            minimum = {
                                x = entity.position.x,
                                y = entity.position.y
                            },
                            maximum = {
                                x = entity.position.x,
                                y = entity.position.y

                            },
                            required_items = {},
                        }
                    else -- add to existing queued_chunk
                        global.construct_queue[chunk_surface][key][entity_key] = entity
                        if entity.position.x < global.construct_queue[chunk_surface][key]['minimum'].x then
                            global.construct_queue[chunk_surface][key]['minimum'].x = entity.position.x
                        elseif entity.position.x > global.construct_queue[chunk_surface][key]['maximum'].x then
                            global.construct_queue[chunk_surface][key]['maximum'].x = entity.position.x
                        end
                        if entity.position.y < global.construct_queue[chunk_surface][key]['minimum'].y then
                            global.construct_queue[chunk_surface][key]['minimum'].y = entity.position.y
                        elseif entity.position.y > global.construct_queue[chunk_surface][key]['maximum'].y then
                            global.construct_queue[chunk_surface][key]['maximum'].y = entity.position.y
                        end
                    end
                    -- to use for requesting stuff to constructron
                    if not (entity.type == 'item-request-proxy') then
                        for index, item in ipairs(entity.ghost_prototype.items_to_place_this) do
                            global.construct_queue[chunk_surface][key]['required_items'][item.name] =
                                (global.construct_queue[chunk_surface][key]['required_items'][item.name] or 0) + item.count
                        end
                    end
                    -- for modules
                    if entity.type == 'entity-ghost' or entity.type == 'item-request-proxy' then
                        for name, count in pairs(entity.item_requests) do
                            global.construct_queue[chunk_surface][key]['required_items'][name] =
                                (global.construct_queue[chunk_surface][key]['required_items'][name] or 0) + count
                        end
                    end
                else
                    break
                end
            else
                break
            end
        end
    end
end

function add_deconstruction_entities_to_chunks()
    if global.deconstruction_entities[1] and (game.tick - (global.deconstruct_marked_tick or 0)) > job_start_delay then -- if the entity isn't deconstructed in 5 seconds or 300 ticks(default setting).
        for i = 1, entity_per_tick do
            -- local entity = table.remove(global.deconstruction_entities)
            local ghost_count = global.deconstruction_entities_count
            local entity = global.deconstruction_entities[ghost_count]
            if ghost_count > 0 then
                global.deconstruction_entities[ghost_count] = nil
                global.deconstruction_entities_count = ghost_count - 1
                if entity.valid then
                    local chunk = chunk_from_position(entity.position)
                    local key = chunk.y .. ',' .. chunk.x
                    local chunk_surface = entity.surface.index
                    local entity_key = entity.position.y .. ',' .. entity.position.x
                    if not global.deconstruct_queue[chunk_surface][key] then -- initialize queued_chunk
                        global.deconstruct_queue[chunk_surface][key] = {
                            key = key,
                            surface = entity.surface.index,
                            entity_key = entity,
                            position = position_from_chunk(chunk),
                            area = get_area_from_chunk(chunk),
                            minimum = {
                                x = entity.position.x,
                                y = entity.position.y
                            },
                            maximum = {
                                x = entity.position.x,
                                y = entity.position.y

                            },
                            required_items = {},
                            trash_items = {}
                        }
                    else -- add to existing queued_chunk
                        global.deconstruct_queue[chunk_surface][key][entity_key] = entity
                        if entity.position.x < global.deconstruct_queue[chunk_surface][key]['minimum'].x then
                            global.deconstruct_queue[chunk_surface][key]['minimum'].x = entity.position.x
                        elseif entity.position.x > global.deconstruct_queue[chunk_surface][key]['maximum'].x then
                            global.deconstruct_queue[chunk_surface][key]['maximum'].x = entity.position.x
                        end
                        if entity.position.y < global.deconstruct_queue[chunk_surface][key]['minimum'].y then
                            global.deconstruct_queue[chunk_surface][key]['minimum'].y = entity.position.y
                        elseif entity.position.y > global.deconstruct_queue[chunk_surface][key]['maximum'].y then
                            global.deconstruct_queue[chunk_surface][key]['maximum'].y = entity.position.y
                        end
                    end
                    if entity.type == "cliff" then
                        global.deconstruct_queue[chunk_surface][key]['required_items']['cliff-explosives'] = (global.deconstruct_queue[chunk_surface][key]['required_items']['cliff-explosives'] or 0) + 1
                    end
                    if entity.prototype.mineable_properties.products then
                        for index, item in ipairs(entity.prototype.mineable_properties.products) do
                            local amount = item.amount or item.amount_max
                            global.deconstruct_queue[chunk_surface][key]['trash_items'][item.name] = (global.deconstruct_queue[chunk_surface][key]['trash_items'][item.name] or 0) + amount
                        end
                    end
                else
                    break
                end
            else
                break
            end
        end
    end
end

function add_upgrade_entities_to_chunks()
    if global.upgrade_entities[1] and (game.tick - (global.upgrade_marked_tick or 0)) > job_start_delay then -- if the entity isn't upgraded in 5 seconds or 300 ticks(default setting).
        for i = 1, entity_per_tick do
            local obj = table.remove(global.upgrade_entities)
            if not obj then break end
            local entity = obj['entity']
            local target = obj['target']
            if entity and entity.valid then
                local chunk = chunk_from_position(entity.position)
                local key = chunk.y .. ',' .. chunk.x
                local chunk_surface = entity.surface.index
                if not global.upgrade_queue[chunk_surface][key] then -- initialize queued_chunk
                    global.upgrade_queue[chunk_surface][key] = {
                        key = key,
                        surface = entity.surface.index,
                        entity_key = entity,
                        position = position_from_chunk(chunk),
                        area = get_area_from_chunk(chunk),
                        minimum = {
                            x = entity.position.x,
                            y = entity.position.y
                        },
                        maximum = {
                            x = entity.position.x,
                            y = entity.position.y

                        },
                        required_items = {},
                    }
                else -- add to existing queued_chunk
                    if entity.position.x < global.upgrade_queue[chunk_surface][key]['minimum'].x then
                        global.upgrade_queue[chunk_surface][key]['minimum'].x = entity.position.x
                    elseif entity.position.x > global.upgrade_queue[chunk_surface][key]['maximum'].x then
                        global.upgrade_queue[chunk_surface][key]['maximum'].x = entity.position.x
                    end
                    if entity.position.y < global.upgrade_queue[chunk_surface][key]['minimum'].y then
                        global.upgrade_queue[chunk_surface][key]['minimum'].y = entity.position.y
                    elseif entity.position.y > global.upgrade_queue[chunk_surface][key]['maximum'].y then
                        global.upgrade_queue[chunk_surface][key]['maximum'].y = entity.position.y
                    end
                end
                for index, item in ipairs(target.items_to_place_this) do
                    global.upgrade_queue[chunk_surface][key]['required_items'][item.name] =
                        (global.upgrade_queue[chunk_surface][key]['required_items'][item.name] or 0) + item.count
                end
            else
                break
            end
        end
    end
end

script.on_nth_tick(1, function(event)
    if event.tick % 3 == 0 then
        add_deconstruction_entities_to_chunks()
    elseif event.tick % 3 == 1 then
        add_ghosts_to_chunks()
    elseif event.tick % 3 == 2 then
        add_upgrade_entities_to_chunks()
    end
end)

function robots_inactive(constructron)
    if constructron.valid then
        local network = constructron.logistic_network
        local cell = network.cells[1]
        local all_construction_robots = network.all_construction_robots
        local stationed_bots = cell.stationed_construction_robot_count
        local charging_robots = cell.charging_robots
        local to_charge_robots = cell.to_charge_robots
        local active_bots = (all_construction_robots) - (stationed_bots)
        local inventory = constructron.get_inventory(defines.inventory.spider_trunk)
        local empty_stacks = inventory.count_empty_stacks()

        if (network and (active_bots == 0)) or 
        ((active_bots >= 1) and not next(charging_robots) and not next(to_charge_robots) and (empty_stacks == 0)) then
            for i, equipment in pairs(constructron.grid.equipment) do
                if equipment.type == 'roboport-equipment' then
                    if (equipment.energy / equipment.max_energy) < 0.95 then
                        return false
                    end
                end
            end
            return true
        end
        return false
    else
        invalid = true
        return invalid
    end
end

function do_until_leave(job)
    -- action is what to do, a function.
    -- action_args is going to be unpacked to action function. first argument of action must be constructron.
    -- leave_condition is a function, leave_args is a table to unpack to leave_condition as arguments
    -- leave_condition should have constructron as first argument
    if job.constructrons[1] then
        if not job.active then
            if (job.action == 'go_to_position') then
                new_pos_goal = actions[job.action](job.constructrons, table.unpack(job.action_args or {}))
                job.leave_args[1] = new_pos_goal
            else
                actions[job.action](job.constructrons, table.unpack(job.action_args or {}))
            end
        end
        if job.start_tick == nil then
            job.start_tick = 2
        end
        if conditions[job.leave_condition](job.constructrons, table.unpack(job.leave_args or {})) then
            table.remove(global.job_bundles[job.bundle_index], 1)
            -- for c, constructron in ipairs(constructrons) do
            --     table.remove(global.constructron_jobs[constructron.unit_number], 1)
            -- end
            return true -- returning true means you can remove this job from job list
        elseif (job.action == 'go_to_position') and (game.tick - job.start_tick) > 600 then
            for c, constructron in ipairs(job.constructrons) do
                if not constructron.autopilot_destination then
                    actions[job.action](job.constructrons, table.unpack(job.action_args or {}))
                    job.start_tick = game.tick
                end
            end
        elseif (job.action == 'request_items') and (game.tick - job.start_tick) > max_jobtime then
            local closest_station = get_closest_service_station(job.constructrons[1])
            for unit_number, station in pairs(job.unused_stations) do
                if not station.valid then
                    job.unused_stations[unit_number] = nil
                end
            end
            job.unused_stations[closest_station.unit_number] = nil
            if not (next(job.unused_stations)) then
                job.unused_stations = get_service_stations(job.constructrons[1].surface.index)
                if not #job.unused_stations == 1 then
                    job.unused_stations[closest_station.unit_number] = nil
                end
            end
            next_station = get_closest_unused_service_station(job.constructrons[1], job.unused_stations)
            for c, constructron in ipairs(job.constructrons) do
                request_path({constructron}, next_station.position)
            end
            job.start_tick = game.tick
            DebugLog('request_items action timed out, moving to new station')
        end
    else
        invalid = true
        return invalid
    end
end

actions = {
    go_to_position = function(constructrons, position, find_path)
        DebugLog('ACTION: go_to_position')
        if find_path then
            local new_goal = request_path(constructrons, position)
            return new_goal
        else
            for c, constructron in ipairs(constructrons) do
                constructron.autopilot_destination = position
            end
        end
        for c, constructron in ipairs(constructrons) do
            set_constructron_status(constructron, 'on_transit', true)
        end
    end,
    build = function(constructrons)
        DebugLog('ACTION: build')
        -- I want to enable construction only when in the construction area
        -- however there doesn't seem to be a way to do this with the current api
        -- enable_logistic_while_moving is doing somewhat what I want however I wish there was a way to check
        -- whether or not logistics was enabled. there doesn't seem to be a way.
        -- so I'm counting on robots that they will be triggered in two second or 120 ticks.
        if constructrons[1].valid then
            for c, constructron in ipairs(constructrons) do
                constructron.enable_logistics_while_moving = false
                set_constructron_status(constructron, 'build_tick', game.tick)
            end
        else
            invalid = true
            return invalid
        end
        -- enable construct 
    end,
    deconstruct = function(constructrons)
        DebugLog('ACTION: deconstruct')
        -- I want to enable construction only when in the construction area
        -- however there doesn't seem to be a way to do this with the current api
        -- enable_logistic_while_moving is doing somewhat what I want however I wish there was a way to check
        -- whether or not logistics was enabled. there doesn't seem to be a way.
        -- so I'm counting on robots that they will be triggered in two second or 120 ticks.
        for c, constructron in ipairs(constructrons) do
            if constructron.valid then
                constructron.enable_logistics_while_moving = false
                set_constructron_status(constructron, 'deconstruct_tick', game.tick)
            else
                invalid = true
                return invalid
            end
        end
        -- enable construct 
    end,
    request_items = function(constructrons, items)
        DebugLog('ACTION: request_items')
        local closest_station = get_closest_service_station(constructrons[1]) -- they must go to the same station even if they are not in the same station.
        for c, constructron in ipairs(constructrons) do
            request_path({constructron}, closest_station.position) -- they can be elsewhere though. they don't have to start in the same place.
            local slot = 1
            -- set every item that isn't placable as zero.
            -- for i, name in ipairs({'stone', 'coal', 'wood', 'iron-ore', 'copper-ore', 'uranium-ore'}) do
            --     constructron.set_vehicle_logistic_slot(slot, {
            --         name = name,
            --         min = 0,
            --         max = 0
            --     })
            --     slot = slot + 1
            -- end
            for name, count in pairs(items) do
                constructron.set_vehicle_logistic_slot(slot, {
                    name = name,
                    min = count,
                    max = count
                })
                slot = slot + 1
            end
        end
    end,
    clear_items = function(constructrons)
        DebugLog('ACTION: clear_items')
        -- for when the constructron returns to service station and needs to empty it's inventory.
        local slot = 1
            for c, constructron in ipairs(constructrons) do
                if constructron.valid then
                    local inventory = constructron.get_inventory(defines.inventory.spider_trunk)
                    local filtered_items = {}
                    for i = 1, #inventory do
                        local item = inventory[i]
                        if item.valid_for_read then
                            if not (item.prototype.place_result and item.prototype.place_result.type == "construction-robot") then
                                if not filtered_items[item.name] then 
                                    constructron.set_vehicle_logistic_slot(slot, {
                                        name=item.name,
                                        min = 0,
                                        max = 0
                                    })
                                    slot = slot + 1
                                    filtered_items[item.name] = true
                                end
                            end
                        end
                    end
                else
                    invalid = true
                    return invalid
                end
            end
    end,
    retire = function(constructrons)
        DebugLog('ACTION: retire')
        for c, constructron in ipairs(constructrons) do
            if constructron.valid then
                set_constructron_status(constructron, 'busy', false)
                paint_constructron(constructron, 'idle')
            else
                invalid = true
                return invalid
            end
        end
    end,
    add_to_check_chunk_done_queue = function(constructrons, chunk)
        DebugLog('ACTION: add_to_check_chunk_done_queue')
        local entity_names = {}
        for name, count in pairs(chunk.required_items) do
            table.insert(entity_names, name)
        end
        surface = game.surfaces[chunk.surface]
        ghosts = surface.find_entities_filtered{
            area = {chunk.minimum, chunk.maximum},
            type = "entity-ghost",
            ghost_name = entity_names,
        }
        if next(ghosts or {}) then -- if there are ghosts because inventory doesn't have the items for them, add them to be built for the next job
            game.print('added ' .. #ghosts .. ' unbuilt ghosts.')

            for i, entity in ipairs(ghosts) do
                local ghost_count = global.ghost_entities_count
                ghost_count = ghost_count + 1
                global.ghost_entities_count = ghost_count
                global.ghost_entities[ghost_count] = entity
            end
        end
    end,
    check_decon_chunk = function(constructrons, chunk)
        DebugLog('ACTION: check_decon_chunk')
        local entity_names = {}
        for name, count in pairs(chunk.required_items) do
            table.insert(entity_names, name)
        end
        surface = game.surfaces[chunk.surface]
        decons = surface.find_entities_filtered{
            area = {chunk.minimum, chunk.maximum},
            to_be_deconstructed = true,
            ghost_name = entity_names,
        }
        if next(decons or {}) then -- if there are ghosts because inventory doesn't have the items for them, add them to be built for the next job
            game.print('added ' .. #decons .. ' to be deconstructed.')

            for i, entity in ipairs(decons) do
                local decon_count = global.deconstruction_entities_count
                decon_count = decon_count + 1
                global.deconstruction_entities_count = decon_count
                global.deconstruction_entities[decon_count] = entity
            end
        end
    end
}

conditions = {
    position_done = function(constructrons, position) -- this is condition for action "go_to_position"
        VisualDebugText("Moving to position", constructrons[1])
        for c, constructron in ipairs(constructrons) do
            if (constructron.valid == false) then 
                invalid = true
                return invalid
            end
            if (distance_between(constructron.position, position) > 5) then -- or not robots_inactive(constructron) then
                return false
            end
        end
        return true
    end,
    build_done = function(constructrons, items, minimum_position, maximum_position)
        VisualDebugText("Constructing", constructrons[1])
        if constructrons[1].valid then
            for c, constructron in ipairs(constructrons) do
                local bots_inactive = robots_inactive(constructron)
                if not bots_inactive then
                    return false
                end
            end
            if (game.tick - (get_constructron_status(constructrons[1], 'build_tick'))) > 120 then
                return true
            end
        else
            invalid = true
            return invalid
        end
    end,
    deconstruction_done = function(constructrons)
        VisualDebugText("Deconstructing", constructrons[1])
        if constructrons[1].valid then
            for c, constructron in ipairs(constructrons) do
                if not robots_inactive(constructron) then
                    return false
                end
            end
            if game.tick - get_constructron_status(constructrons[1], 'deconstruct_tick') > 120 then
                return true
            end
        else
            invalid = true
            return invalid
        end
    end,
    request_done = function(constructrons)
        VisualDebugText("Processing logistics", constructrons[1])
        if constructrons_need_reload(constructrons) then
            return false
        else
            for c, constructron in ipairs(constructrons) do
                if constructron.valid then
                    for i = 1, constructron.request_slot_count do
                        constructron.clear_vehicle_logistic_slot(i)
                    end
                else
                    invalid = true
                    return invalid
                end
            end
        end
        return true
    end,
    pass = function(constructrons)
        return true
    end
}

function give_job(constructrons, job) -- this doesn't look like it is used
    -- we should give the job only to the leader aka constructrons[1]
    if not global.constructron_jobs[constructrons[1].unit_number] then
        global.constructron_jobs[constructrons[1].unit_number] = {}
    end
    table.insert(global.constructron_jobs[constructrons[1].unit_number], job)
end

function create_job(job_bundle_index, job)
    if not global.job_bundles then
        global.job_bundles = {}
    end
    if not global.job_bundles[job_bundle_index] then
        global.job_bundles[job_bundle_index] = {}
    end
    local index = #global.job_bundles[job_bundle_index] + 1
    job.index = index
    job.bundle_index = job_bundle_index
    global.job_bundles[job_bundle_index][index] = job
end

function get_closest_object(objects, position)
    -- actually returns object index or key rather than object.
    local min_distance
    local object_index
    local iterator
    if not objects[1] then
        iterator = pairs
    else
        iterator = ipairs
    end
    for i, object in iterator(objects) do
        local distance = distance_between(object.position, position)
            if not min_distance or (distance < min_distance) then
                min_distance = distance
                object_index = i
            end
    end
    return object_index
end

function get_job(constructrons)
    function get_chunks_and_constructrons(queued_chunks, preselected_constructrons, max_constructron)
        local inventory = preselected_constructrons[1].get_inventory(defines.inventory.spider_trunk) -- only checking if things can fit in the first constructron. expecting others to be the exact same.
        local empty_stack_count = inventory.count_empty_stacks()
        local selected_chunks = {}
        local selected_constructrons = {}

        function get_job_chunks_and_constructrons(chunks, constructron_count, total_required_slots, requested_items)
            local merged_chunk
            for i, chunk1 in ipairs(chunks) do
                for j, chunk2 in ipairs(chunks) do
                    if not (i==j) then
                        local merged_area = merge_direct_neighbour(chunk1.area, chunk2.area)
                        if merged_area then
                            local required_slots1
                            local required_slots2
                            if not chunk1.merged then
                                required_slots1 = calculate_required_inventory_slot_count(chunk1.required_items, constructron_count)
                                required_slots1 = required_slots1 + calculate_required_inventory_slot_count(chunk1.trash_items or {}, constructron_count)
                                for name, count in pairs(chunk1['required_items']) do
                                    requested_items[name] = math.ceil(((requested_items[name] or 0)*constructron_count + count) / constructron_count)
                                end
                            else
                                required_slots1 = 0
                            end
                            if not chunk2.merged then
                                required_slots2 = calculate_required_inventory_slot_count(chunk2.required_items, constructron_count)
                                required_slots2 = required_slots2 + calculate_required_inventory_slot_count(chunk2.trash_items or {}, constructron_count)
                                for name, count in pairs(chunk2['required_items']) do
                                    requested_items[name] = math.ceil(((requested_items[name] or 0)*constructron_count + count) / constructron_count)
                                end
                            else
                                required_slots2 = 0
                            end
                            if ((total_required_slots + required_slots1 + required_slots2) < empty_stack_count) then
                                total_required_slots = total_required_slots + required_slots1 + required_slots2
                                merged_chunk = merge_neighbour_chunks(merged_area, chunk1, chunk2)
                                merged_chunk.merged = true

                                -- create a new table for remaining chunks
                                local remaining_chunks = {}
                                table.insert(remaining_chunks, merged_chunk)
                                for k, chunk in ipairs(chunks) do
                                    if (not (k == i)) and (not (k == j)) then
                                        table.insert(remaining_chunks, chunk)
                                    end
                                end
                                return get_job_chunks_and_constructrons(remaining_chunks, constructron_count, total_required_slots, requested_items)
                            elseif constructron_count < max_constructron and constructron_count < #preselected_constructrons then
                                -- use the original chunks and empty merge_chunks and start over
                                return get_job_chunks_and_constructrons(queued_chunks, constructron_count+1, 0, {})
                            end
                        else
                            local area1 = chunk1.area
                            local area2 = chunk2.area
                        end
                    end
                end
            end
            local constructrons = {}
            for c=1,constructron_count do
                table.insert(constructrons, preselected_constructrons[c])
            end

            -- if the chunks didn't merge. there are unmerged chunks. they should be added as job if they can be.
            local unused_chunks = {}
            local used_chunks = {}
            requested_items = {}
            total_required_slots = 0

            for i, chunk in ipairs(chunks) do
                local required_slots = calculate_required_inventory_slot_count(chunk.required_items, constructron_count)
                required_slots = required_slots + calculate_required_inventory_slot_count(chunk.trash_items or {}, constructron_count)
                if ((total_required_slots + required_slots) < empty_stack_count) then
                    total_required_slots = total_required_slots + required_slots
                    for name, count in pairs(chunk['required_items']) do
                        requested_items[name] = math.ceil(((requested_items[name] or 0)*constructron_count + count) / constructron_count)
                    end
                    table.insert(used_chunks, chunk)
                else
                    table.insert(unused_chunks, chunk)
                end
            end

            used_chunks.requested_items = requested_items
            return used_chunks, constructrons, unused_chunks
        end
        return get_job_chunks_and_constructrons(queued_chunks, 1, 0, {})
    end

    local managed_surfaces = game.surfaces -- revisit as all surfaces are scanned, even ones without service stations or constructrons.

    for surface_name, surface in pairs(managed_surfaces) do -- iterate each surface
        global.construct_queue[surface.index] = global.construct_queue[surface.index] or {}
        global.deconstruct_queue[surface.index] = global.deconstruct_queue[surface.index] or {}
        global.upgrade_queue[surface.index] = global.upgrade_queue[surface.index] or {}

        if (next(global.construct_queue[surface.index]) or next(global.deconstruct_queue[surface.index]) or next(global.upgrade_queue[surface.index])) then -- this means they are processed as chunks or it's empty.
            
            local max_worker = settings.global['max-worker-per-job'].value
            local available_constructrons = {}
            local chunks = {}
            local job_type
            
            for c, constructron in pairs(constructrons) do
                local desired_robot_count = settings.global["desired_robot_count"].value
                
                if (constructron.surface.index == surface.index) and constructron.logistic_cell and (constructron.logistic_network.all_construction_robots >= desired_robot_count) and not get_constructron_status(constructron, 'busy') then
                    table.insert(available_constructrons, constructron)
                elseif not constructron.logistic_cell then
                    VisualDebugText("Needs Equipment", constructron)
                elseif (constructron.logistic_network.all_construction_robots < desired_robot_count) and (constructron.autopilot_destination == nil) then
                    DebugLog('ACTION: Stage')
                    VisualDebugText("Requesting Construction Robots", constructron)
                    constructron.enable_logistics_while_moving = false
                    local closest_station = get_closest_service_station(constructron) -- they must go to the same station even if they are not in the same station.
                    local desired_robot_name = settings.global["desired_robot_name"].value
                    request_path({constructron}, closest_station.position) -- they can be elsewhere though. they don't have to start in the same place.
                    local slot = 1
                    constructron.set_vehicle_logistic_slot(slot, {
                        name = desired_robot_name,
                        min = desired_robot_count,
                        max = desired_robot_count
                    })
                end
            end

            if #available_constructrons < 1 then return end

            if next(global.deconstruct_queue[surface.index]) then --deconstruction have priority over construction.
                for key, chunk in pairs(global.deconstruct_queue[surface.index]) do
                    table.insert(chunks, chunk)
                end
                job_type = 'deconstruct'

            elseif next(global.construct_queue[surface.index]) then
                for key, chunk in pairs(global.construct_queue[surface.index]) do
                    table.insert(chunks, chunk)
                end
                job_type = 'construct'

            elseif next(global.upgrade_queue[surface.index]) then
                for key, chunk in pairs(global.upgrade_queue[surface.index]) do
                    table.insert(chunks, chunk)
                end
                job_type = 'upgrade'
            end

            if not next(chunks) then return end

            local combined_chunks, selected_constructrons, unused_chunks = get_chunks_and_constructrons(chunks, available_constructrons, max_worker)

            if job_type == 'deconstruct' then
                for key, value in pairs(global.deconstruct_queue[surface.index]) do
                    global.deconstruct_queue[surface.index][key] = nil
                end
                for i, chunk in ipairs(unused_chunks) do
                    global.deconstruct_queue[surface.index][chunk.key] = chunk
                end

            elseif job_type == 'construct' then
                for key, value in pairs(global.construct_queue[surface.index]) do
                    global.construct_queue[surface.index][key] = nil
                end
                for i, chunk in ipairs(unused_chunks) do
                        global.construct_queue[surface.index][chunk.key] = chunk
                end

            elseif job_type == 'upgrade' then
                for key, value in pairs(global.upgrade_queue[surface.index]) do
                    global.upgrade_queue[surface.index][key] = nil
                end
                for i, chunk in ipairs(unused_chunks) do
                    global.upgrade_queue[surface.index][chunk.key] = chunk
                end
            end

            local request_items_job = {
                action = 'request_items',
                action_args = {combined_chunks.requested_items},
                leave_condition = 'request_done',
                constructrons = selected_constructrons,
                start_tick = game.tick,
                unused_stations = get_service_stations(selected_constructrons[1].surface.index)
            }

            global.job_bundle_index = (global.job_bundle_index or 0) + 1
            create_job(global.job_bundle_index, request_items_job)
            for i, chunk in ipairs(combined_chunks) do
                -- local chunk_index = get_closest_object(combined_chunks, constructrons[1].position)
                -- local chunk = table.remove(combined_chunks, chunk_index)
                chunk['positions'] = calculate_construct_positions({chunk.minimum, chunk.maximum}, selected_constructrons[1].logistic_cell.construction_radius*0.90) -- 10% tolerance
                chunk['surface'] = surface.index
                local find_path = false
                for p, position in ipairs(chunk.positions) do
                    if p == 1 then find_path = true end
                    local go_to_position_job = {
                        action = 'go_to_position',
                        action_args = {position, find_path},
                        leave_condition = 'position_done',
                        leave_args = {position},
                        constructrons = selected_constructrons,
                        start_tick = game.tick
                    }
                    create_job(global.job_bundle_index, go_to_position_job)
                    if not (job_type == 'deconstruct') then
                        local build_job = {
                            action = 'build',
                            leave_condition = 'build_done',
                            leave_args = {chunk.required_items, chunk.minimum, chunk.maximum},
                            constructrons = selected_constructrons
                        }
                        create_job(global.job_bundle_index, build_job)
                        for c, constructron in ipairs(selected_constructrons) do
                            paint_constructron(constructron, 'construct')
                        end
                    elseif job_type == 'deconstruct' then
                        local deconstruction_job = {
                            action = 'deconstruct',
                            leave_condition = 'deconstruction_done',
                            constructrons = selected_constructrons
                        }
                        create_job(global.job_bundle_index, deconstruction_job)
                    end
                    for c, constructron in ipairs(selected_constructrons) do
                        paint_constructron(constructron, job_type)
                    end
                end
                if job_type == 'construct' then
                    local add_to_check_chunk_done_queue_job = {
                        action = 'add_to_check_chunk_done_queue',
                        action_args = {chunk},
                        leave_condition = 'pass', -- there is no leave condition 
                        constructrons = selected_constructrons,
                    }
                    create_job(global.job_bundle_index, add_to_check_chunk_done_queue_job)
                end
                if job_type == 'deconstruct' then
                    local check_decon_chunk_job = {
                        action = 'check_decon_chunk',
                        action_args = {chunk},
                        leave_condition = 'pass', -- there is no leave condition 
                        constructrons = selected_constructrons,
                    }
                    create_job(global.job_bundle_index, check_decon_chunk_job)
                end
            end
            -- go back to a service_station when job is done.
            local closest_station = get_closest_service_station(selected_constructrons[1])
            local home_position = closest_station.position
            local go_to_home_job = {
                action = 'go_to_position',
                action_args = {home_position, true},
                leave_condition = 'position_done',
                leave_args = {home_position},
                constructrons = selected_constructrons,
                start_tick = game.tick
            }
            create_job(global.job_bundle_index, go_to_home_job)
            local empty_inventory_job = {
                action = 'clear_items',
                leave_condition = 'request_done',
                constructrons = selected_constructrons
            }
            create_job(global.job_bundle_index, empty_inventory_job)
            local retire_job = {
                action = 'retire',
                leave_condition = 'pass',
                leave_args = {home_position},
                constructrons = selected_constructrons
            }
            create_job(global.job_bundle_index, retire_job)
        end
    end
end

function do_job(job_bundles)
    if not next(job_bundles) then
        return
    end

    for i, job_bundle in pairs(job_bundles) do
        local job = job_bundle[1]
        if job then
            for c, constructron in ipairs(job.constructrons) do
                if not job.active then
                    set_constructron_status(constructron, 'busy', true)
                end
            end
            if job.constructrons[1] then
                do_until_leave(job)
                job.active = true
            else
                invalid = true
                return invalid
            end
        else
            job_bundles[i] = nil
        end
    end
end

script.on_nth_tick(60, function(event)
    local constructrons = global.constructrons
    local service_stations = global.service_stations
    get_job(constructrons or {})
    do_job(global.job_bundles or {})
end)

script.on_nth_tick(54000, function(event)
    DebugLog('surface job cleanup')
    local constructrons = global.constructrons
    local service_stations = global.service_stations
    for s, surface in pairs(game.surfaces) do
        if (global.constructrons_count[surface.index] <= 0) or (global.stations_count[surface.index] <= 0) then
            DebugLog('No Constructrons or Service Stations found on ' .. surface.name .. '. All job queues cleared!')
            global.construct_queue[surface.index] = {}
            global.deconstruct_queue[surface.index] = {}
            global.upgrade_queue[surface.index] = {}
            global.constructrons_count[surface.index] = 0 -- in case it somehow goes below 0
            global.stations_count[surface.index] = 0 -- in case it somehow goes below 0
        end
    end
end)

function remove_entity_from_queue(queue, entity)
    local chunk = chunk_from_position(entity.position)
    local chunk_key = chunk.y .. ',' .. chunk.x
    local quque_entity = queue[chunk_key]
    if quque_entity then
        local entity_key = entity.position.y .. ',' .. entity.position.x
        if quque_entity[entity_key] then
            quque_entity[entity_key] = nil
            for i, item in ipairs(entity.prototype) do
                quque_entity.required_items[item.name] = (quque_entity.required_items[item.name] or item.count) - item.count
            end
        end
    end
end

local function is_floor_tile(entity_name)
    local floor_tiles = {"landfill","se-space-platform-scaffold","se-space-platform-plating","se-spaceship-floor"}
    --ToDo:
    --  find landfill-like tiles based on collision layer
    --  this list should be build at loading time not everytime
    return table_has_value(floor_tiles, entity_name)
end

script.on_event(defines.events.on_built_entity, function(event) -- for entity creation
    local entity = event.created_entity
    local entity_type = entity.type
    if entity_type == 'entity-ghost' or entity_type == 'tile-ghost' then
        local entity_name = entity.ghost_name
        -- Need to separate ghosts and tiles in different tables
        if global.ignored_entities[entity_name] == nil then
            local items_to_place_this = entity.ghost_prototype.items_to_place_this
            global.ignored_entities[entity_name] = game.item_prototypes[items_to_place_this[1].name].has_flag('hidden')
            if is_floor_tile(entity_name) then -- we need to find a way to improve pathing before floor tiles can be built. So ignore landfill and similiar tiles.
                global.ignored_entities[entity_name] = true
            end
        end
        if not global.ignored_entities[entity_name] == true then
            local ghost_count = global.ghost_entities_count
            ghost_count = ghost_count + 1
            global.ghost_entities_count = ghost_count
            global.ghost_entities[ghost_count] = entity
            global.ghost_tick = event.tick -- to look at later, updating a global each time a ghost is created, should this be per ghost?
        end
    elseif entity.name == 'constructron' then
        global.constructrons[entity.unit_number] = entity
        local registration_number = script.register_on_entity_destroyed(entity)
        global.registered_entities[registration_number] = {name = "constructron", surface = entity.surface.index}
        global.constructrons_count[entity.surface.index] = global.constructrons_count[entity.surface.index] + 1
    elseif entity.name == "service_station" then
        global.service_stations[entity.unit_number] = entity
        local registration_number = script.register_on_entity_destroyed(entity)
        global.registered_entities[registration_number] = {name = "service_station", surface = entity.surface.index}
        global.stations_count[entity.surface.index] = global.stations_count[entity.surface.index] + 1
    end
end)

script.on_event(defines.events.script_raised_built, function(event) -- for mods
    if not event.entity.name == 'item-request-proxy' then
        local entity = event.created_entity
        local entity_type = entity.type or {}
        if entity_type == 'entity-ghost' or entity_type == 'tile-ghost' then
            local entity_name = entity.ghost_name
            -- Need to separate ghosts and tiles in different tables
            if global.ignored_entities[entity_name] == nil then
                local items_to_place_this = entity.ghost_prototype.items_to_place_this
                global.ignored_entities[entity_name] = game.item_prototypes[items_to_place_this[1].name].has_flag('hidden')
                if is_floor_tile(entity_name)  then -- we need to find a way to improve pathing before floor tiles can be built. So ignore landfill and similiar tiles.
                    global.ignored_entities[entity_name] = true
                end
            end
            if not global.ignored_entities[entity_name] == true then
                local ghost_count = global.ghost_entities_count
                ghost_count = ghost_count + 1
                global.ghost_entities_count = ghost_count
                global.ghost_entities[ghost_count] = entity
                global.ghost_tick = event.tick -- to look at later, updating a global each time a ghost is created, should this be per ghost?
            end
        elseif entity.name == 'constructron' then
            global.constructrons[entity.unit_number] = entity
            local registration_number = script.register_on_entity_destroyed(entity)
            global.registered_entities[registration_number] = {name = "constructron", surface = entity.surface.index}
            global.constructrons_count[entity.surface.index] = global.constructrons_count[entity.surface.index] + 1
        elseif entity.name == "service_station" then
            global.service_stations[entity.unit_number] = entity
            local registration_number = script.register_on_entity_destroyed(entity)
            global.registered_entities[registration_number] = {name = "service_station", surface = entity.surface.index}
            global.stations_count[entity.surface.index] = global.stations_count[entity.surface.index] + 1
        end
    elseif event.entity.type == 'item-request-proxy' then
        local entity = event.entity
        local ghost_count = global.ghost_entities_count
        ghost_count = ghost_count + 1
        global.ghost_entities_count = ghost_count
        global.ghost_entities[ghost_count] = entity
        global.ghost_tick = event.tick -- to look at later, updating a global each time a ghost is created, should this be per ghost?
    end
end)

script.on_event(defines.events.on_post_entity_died, function(event) -- for entities that die and need rebuilding
    local entity = event.ghost
    if entity and entity.type == 'entity-ghost' then
        local ghost_count = global.ghost_entities_count
        ghost_count = ghost_count + 1
        global.ghost_entities_count = ghost_count
        global.ghost_entities[ghost_count] = entity
        global.ghost_tick = event.tick
    end
    -- if event.prototype.name == 'constructron' then
    --     global.constructrons[event.unit_number] = nil  -- could be redundant as entities are now registered
    -- elseif event.prototype.name == 'service_station' then
    --     global.service_stations[event.unit_number] = nil  -- could be redundant as entities are now registered
    -- end
end)

script.on_event(defines.events.on_robot_built_entity, function(event) -- add service_stations to global when built by robots
    local entity = event.created_entity
    if entity.name == "service_station" then
        global.service_stations[entity.unit_number] = entity
        local registration_number = script.register_on_entity_destroyed(entity)
        global.registered_entities[registration_number] = {name = "service_station", surface = entity.surface.index}
        global.stations_count[entity.surface.index] = global.stations_count[entity.surface.index] + 1
    end
end)
---

-- -- remove from deconstruct queue if it's mined/deconstructed
-- script.on_event(defines.events.on_robot_mined_entity, function(event) -- remove service_stations from global when mined by robots
--     local entity = event.entity
--     if entity.name == "service_station" then
--         global.service_stations[entity.unit_number] = nil  -- could be redundant as entities are now registered
--     end
-- end)
---

-- script.on_event(defines.events.on_player_mined_entity, function(event) -- remove service_stations and constructrons from global when mined by player
--     local entity = event.entity
--     if entity.name == "constructron" then
--         global.constructrons[entity.unit_number] = nil  -- could be redundant as entities are now registered
--     elseif entity.name == "service_station" then
--         global.service_stations[entity.unit_number] = nil  -- could be redundant as entities are now registered
--     end
-- end)
---

script.on_event(defines.events.on_marked_for_upgrade, function(event) -- for entity upgrade
    global.upgrade_marked_tick = event.tick
    table.insert(global.upgrade_entities, {entity=event.entity, target=event.target})
end)
---

script.on_event(defines.events.on_marked_for_deconstruction, function(event) -- for entity deconstruction
    global.deconstruct_marked_tick = event.tick
    local decon_count = global.deconstruction_entities_count
    decon_count = decon_count + 1
    global.deconstruction_entities_count = decon_count
    global.deconstruction_entities[decon_count] = event.entity
end, {{filter='name', name="item-on-ground", invert=true}})
---

script.on_event(defines.events.on_surface_created, function(event)
    global.constructrons_count[event.surface_index] = 0
    global.stations_count[event.surface_index] = 0
end)
---

script.on_event(defines.events.on_surface_deleted, function(event)
    index = event.surface_index
    global.construct_queue[index] = nil
    global.deconstruct_queue[index] = nil
    global.upgrade_queue[index] = nil
    global.constructrons_count[index] = nil
    global.stations_count[index] = nil
end)
---

script.on_event(defines.events.on_entity_cloned, function(event)
    local entity = event.destination
    if entity.name == 'constructron' then
        DebugLog('constructron ' .. event.destination.unit_number .. ' Cloned!')
        global.constructrons[entity.unit_number] = entity
        local registration_number = script.register_on_entity_destroyed(entity)
        global.registered_entities[registration_number] = {name = "constructron", surface = entity.surface.index}
        global.constructrons_count[entity.surface.index] = global.constructrons_count[entity.surface.index] + 1        
    elseif entity.name == "service_station" then
        DebugLog('service_station ' .. event.destination.unit_number .. ' Cloned!')
        global.service_stations[entity.unit_number] = entity
        local registration_number = script.register_on_entity_destroyed(entity)
        global.registered_entities[registration_number] = {name = "service_station", surface = entity.surface.index}
        global.stations_count[entity.surface.index] = global.stations_count[entity.surface.index] + 1
    end
end)

script.on_event(defines.events.on_entity_destroyed, function(event)
    if global.registered_entities[event.registration_number] then
        local removed_entity = global.registered_entities[event.registration_number]
        if removed_entity.name == "constructron" then
            local surface = removed_entity.surface
            global.constructrons_count[surface] = global.constructrons_count[surface] - 1
            global.constructrons[event.unit_number] = nil
            DebugLog('constructron ' .. event.unit_number .. ' Destroyed!')
        elseif removed_entity.name == "service_station" then
            local surface = removed_entity.surface
            global.stations_count[surface] = global.stations_count[surface] - 1
            global.service_stations[event.unit_number] = nil
            DebugLog('service_station ' .. event.unit_number .. ' Destroyed!')
        end
        global.registered_entities[event.registration_number] = nil
    end
end)

script.on_event(defines.events.script_raised_destroy, function(event)
    if global.registered_entities[event.registration_number] then
        local removed_entity = global.registered_entities[event.registration_number]
        if removed_entity.name == "constructron" then
            local surface = removed_entity.surface
            global.constructrons_count[surface] = global.constructrons_count[surface] - 1
            global.constructrons[event.unit_number] = nil
            DebugLog('constructron' .. event.unit_number .. 'Destroyed!')
        elseif removed_entity.name == "service_station" then
            local surface = removed_entity.surface
            global.stations_count[surface] = global.stations_count[surface] - 1
            global.service_stations[event.unit_number] = nil
            DebugLog('service_station' .. event.unit_number .. 'Destroyed!')
        end
        global.registered_entities[event.registration_number] = nil
    end
end)

function set_constructron_status(constructron, state, value)
    if constructron.valid then
        if global.constructron_statuses[constructron.unit_number] then
            global.constructron_statuses[constructron.unit_number][state] = value
        else
            global.constructron_statuses[constructron.unit_number] = {}
            global.constructron_statuses[constructron.unit_number][state] = value
        end
    else
        invalid = true
        return invalid
    end
end

function get_constructron_status(constructron, state)
    if constructron then
        if global.constructron_statuses[constructron.unit_number] then
            return global.constructron_statuses[constructron.unit_number][state]
        end
        return nil
    else
        invalid = true
        return invalid
    end
end

function get_closest_service_station(constructron)
    local service_stations = get_service_stations(constructron.surface.index)
    if service_stations then
        for unit_number, station in pairs(service_stations) do
            if not station.valid then
                global.service_stations[unit_number] = nil -- could be redundant as entities are now registered
            end
        end
        local service_station_index = get_closest_object(service_stations, constructron.position)
        return service_stations[service_station_index]
    end
end

function get_closest_unused_service_station(constructron, unused_stations)
    if unused_stations then
        local unused_stations_index = get_closest_object(unused_stations, constructron.position)
        return unused_stations[unused_stations_index]
    end
end

function paint_constructron(constructron, color_state)
    local color
    if color_state == 'idle' then
        color = {r=0.5, g=0.5, b=0.5, a=0.5}
    elseif color_state == 'construct' then
        color = {r=0, g=0.35, b=0.65, a=0.5}
    elseif color_state == 'deconstruct' then
        color = {r=1, g=0.0, b=0, a=0.75}
    elseif color_state == 'upgrade' then
        color = {r=0, g=0.65, b=0, a=0.5}
    end
    constructron.color = color
end
