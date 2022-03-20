local chunk_util = require("__Constructron-Continued__.script.chunk_util")
local custom_lib = require("__Constructron-Continued__.script.custom_lib")
local debug_lib = require("__Constructron-Continued__.script.debug_lib")
local color_lib = require("__Constructron-Continued__.script.color_lib")

local me = {}

me.entity_per_tick = 100

me.pathfinder = {
    -- just a template, check pathfinder.lua for implementation
    request_path = (function(_,_,_) end)
}

me.ensure_globals = function()
    global.constructron_pathfinder_requests = nil
    global.constructron_statuses = global.constructron_statuses or {}
    global.deconstruction_entities = global.deconstruction_entities or {}
    global.upgrade_entities = global.upgrade_entities or {}
    global.construct_queue = global.construct_queue or {}
    global.deconstruct_queue = global.deconstruct_queue or {}
    global.upgrade_queue = global.upgrade_queue or {}
    global.ignored_entities = global.ignored_entities or {}
    global.ghost_entities = global.ghost_entities or {}
    global.job_bundles = global.job_bundles or {}
    global.constructrons = global.constructrons or {}
    global.service_stations = global.service_stations or {}
    global.registered_entities = global.registered_entities or {}
    global.constructrons_count = global.constructrons_count or {}
    global.stations_count = global.stations_count or {}
    global.repair_entities = global.repair_entities or {}
    global.repair_queue = global.repair_queue or {}

    for s, surface in pairs(game.surfaces) do
        global.constructrons_count[surface.index] = global.constructrons_count[surface.index] or 0
        global.stations_count[surface.index] = global.stations_count[surface.index] or 0
        global.construct_queue[surface.index] = global.construct_queue[surface.index] or {}
        global.deconstruct_queue[surface.index] = global.deconstruct_queue[surface.index] or {}
        global.upgrade_queue[surface.index] = global.upgrade_queue[surface.index] or {}
        global.repair_queue[surface.index] = global.repair_queue[surface.index] or {}
    end
end

me.get_service_stations = function(index)
    local stations_on_surface = {}
    for s, station in pairs(global.service_stations) do
        if (index == station.surface.index) then
            table.insert(stations_on_surface, station.unit_number, station)
        end
    end
    return stations_on_surface or {}
end

-- Explain ...
me.get_constructrons = function()
    local constructrons_on_surface = {}
    for c, constructron in pairs(global.constructrons) do
        table.insert(constructrons_on_surface, constructron)
    end
    return constructrons_on_surface
end

me.constructrons_need_reload = function(constructrons)
    for c, constructron in ipairs(constructrons) do
        if not constructron.valid then
            return
        end
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
                if not (((trunk[request.name] or 0) >= request.min) and ((trunk[request.name] or 0) <= request.max)) then
                    return true
                end
            end
        end
    end
    return false
end

me.calculate_required_inventory_slot_count = function(required_items, divisor)
    local slots = 0
    for name, count in pairs(required_items) do
        local stack_size = game.item_prototypes[name].stack_size
        slots = slots + math.ceil(count / stack_size / divisor)
    end
    return slots
end

me.add_entities_to_chunks = function(build_type) -- build_type: deconstruction, upgrade, ghost
    local entities, queue, event_tick
    local entity_counter = 0

    if build_type == "ghost" then
        entities = global.ghost_entities -- array, call by ref
        queue = global.construct_queue -- array, call by ref
        event_tick = global.ghost_tick or 0 -- call by value, it is used as read_only
    elseif build_type == "deconstruction" then
        entities = global.deconstruction_entities -- array, call by ref
        queue = global.deconstruct_queue -- array, call by ref
        event_tick = global.deconstruct_marked_tick or 0 -- call by value, it is used as read_only
    elseif build_type == "upgrade" then
        entities = global.upgrade_entities -- array, call by ref
        queue = global.upgrade_queue -- array, call by ref
        event_tick = global.upgrade_marked_tick or 0 -- call by value, it is used as read_only
    elseif build_type == "repair" then
        entities = global.repair_entities -- array, call by ref
        queue = global.repair_queue -- array, call by ref
        event_tick = global.repair_marked_tick or 0-- call by value, it is used as read_only
    end

    if next(entities) and (game.tick - event_tick) > (settings.global["job-start-delay"].value * 60) then -- if the entity isn't processed in 5 seconds or 300 ticks(default setting).
        for unit_number, entity in pairs(entities) do
            local target_entity

            if entity_counter >= me.entity_per_tick then
                break
            else
                entity_counter = entity_counter + 1
            end

            if build_type == 'upgrade' then
                target_entity = entity.target
                entity = entity.entity
            end

            if not entity or not entity.valid then
                break
            end

            entities[unit_number] = nil

            local chunk = chunk_util.chunk_from_position(entity.position)
            local key = chunk.y .. ',' .. chunk.x
            local entity_surface = entity.surface.index
            local entity_key = entity.position.y .. ',' .. entity.position.x
            queue[entity_surface] = queue[entity_surface] or {}
            if not queue[entity_surface][key] then -- initialize queued_chunk
                queue[entity_surface][key] = {
                    key = key,
                    surface = entity.surface.index,
                    entity_key = entity,
                    position = chunk_util.position_from_chunk(chunk),
                    area = chunk_util.get_area_from_chunk(chunk),
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
                queue[entity_surface][key][entity_key] = entity
                if entity.position.x < queue[entity_surface][key]['minimum'].x then
                    queue[entity_surface][key]['minimum'].x = entity.position.x
                elseif entity.position.x > queue[entity_surface][key]['maximum'].x then
                    queue[entity_surface][key]['maximum'].x = entity.position.x
                end
                if entity.position.y < queue[entity_surface][key]['minimum'].y then
                    queue[entity_surface][key]['minimum'].y = entity.position.y
                elseif entity.position.y > queue[entity_surface][key]['maximum'].y then
                    queue[entity_surface][key]['maximum'].y = entity.position.y
                end
            end
            -- ghosts
            if (build_type == "ghost") and not (entity.type == 'item-request-proxy') then
                for _, item in ipairs(entity.ghost_prototype.items_to_place_this) do
                    if not game.item_prototypes[item.name].has_flag('hidden') then
                        queue[entity_surface][key]['required_items'][item.name] = (queue[entity_surface][key]['required_items'][item.name] or 0) + item.count
                    end
                end
            end
            -- module-requests
            if (build_type ~= "deconstruction") and (entity.type == 'entity-ghost' or entity.type == 'item-request-proxy') then
                for name, count in pairs(entity.item_requests) do
                    if not game.item_prototypes[name].has_flag('hidden') then
                        queue[entity_surface][key]['required_items'][name] = (queue[entity_surface][key]['required_items'][name] or 0) + count
                    end
                end
            end
            -- repair
            if (build_type == "repair") then
                queue[entity_surface][key]['required_items']['repair-pack'] = (queue[entity_surface][key]['required_items']['repair-pack'] or 0) + 3
            end
            -- cliff demolition
            if (build_type == "deconstruction") and entity.type == "cliff" then
                    queue[entity_surface][key]['required_items']['cliff-explosives'] = (queue[entity_surface][key]['required_items']['cliff-explosives'] or 0) + 1
            end
            -- mining/deconstruction results
            if (build_type == "deconstruction") and entity.prototype.mineable_properties.products then
                for _, item in ipairs(entity.prototype.mineable_properties.products) do
                    local amount = item.amount or item.amount_max
                    if not game.item_prototypes[item.name].has_flag('hidden') then
                        queue[entity_surface][key]['trash_items'][item.name] = (queue[entity_surface][key]['trash_items'][item.name] or 0) + amount
                    end
                end
            end
            -- entity upgrades
            if target_entity then
                for _, item in ipairs(target_entity.items_to_place_this) do
                    if not game.item_prototypes[item.name].has_flag('hidden') then
                        queue[entity_surface][key]['required_items'][item.name] = (queue[entity_surface][key]['required_items'][item.name] or 0) + item.count
                    end
                end
            end
        end
    end
end

me.robots_inactive = function(constructron)
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

        if (network and (active_bots == 0)) or ((active_bots >= 1) and not next(charging_robots) and not next(to_charge_robots) and (empty_stacks == 0)) then
            for i, equipment in pairs(constructron.grid.equipment) do -- does not account for only 1 item in grid
                if equipment.type == 'roboport-equipment' then
                    if (equipment.energy / equipment.max_energy) < 0.95 then
                        debug_lib.VisualDebugText("Charging Roboports", constructron)
                        return false
                    end
                end
            end
            return true
        end
        return false
    end
    return true
end

me.do_until_leave = function(job)
    -- action is what to do, a function.
    -- action_args is going to be unpacked to action function. first argument of action must be constructron.
    -- leave_condition is a function, leave_args is a table to unpack to leave_condition as arguments
    -- leave_condition should have constructron as first argument
    if job.constructrons[1] then
        if not job.active then
            if (job.action == 'go_to_position') then
                local new_pos_goal = me.actions[job.action](job.constructrons, table.unpack(job.action_args or {}))
                job.leave_args[1] = new_pos_goal
            else
                me.actions[job.action](job.constructrons, table.unpack(job.action_args or {}))
            end
        end
        if job.start_tick == nil then
            job.start_tick = 2
        end
        if me.conditions[job.leave_condition](job.constructrons, table.unpack(job.leave_args or {})) then
            table.remove(global.job_bundles[job.bundle_index], 1)
            -- for c, constructron in ipairs(constructrons) do
            --     table.remove(global.constructron_jobs[constructron.unit_number], 1)
            -- end
            return true -- returning true means you can remove this job from job list
        elseif (job.action == 'go_to_position') and (game.tick - job.start_tick) > 600 then
            for c, constructron in ipairs(job.constructrons) do
                if constructron.valid then
                    if not constructron.autopilot_destination then
                        me.actions[job.action](job.constructrons, table.unpack(job.action_args or {}))
                        job.start_tick = game.tick
                    end
                else
                    job.constructrons[c] = nil
                end
            end
        elseif (job.action == 'request_items') and (game.tick - job.start_tick) > (settings.global["max-jobtime-per-job"].value * 60 * 60) then
            local closest_station = me.get_closest_service_station(job.constructrons[1])
            for unit_number, station in pairs(job.unused_stations) do
                if not station.valid then
                    job.unused_stations[unit_number] = nil
                end
            end
            job.unused_stations[closest_station.unit_number] = nil
            if not (next(job.unused_stations)) then
                job.unused_stations = me.get_service_stations(job.constructrons[1].surface.index)
                if not #job.unused_stations == 1 then
                    job.unused_stations[closest_station.unit_number] = nil
                end
            end
            local next_station = me.get_closest_unused_service_station(job.constructrons[1], job.unused_stations)
            for _, constructron in ipairs(job.constructrons) do
                me.pathfinder.request_path({constructron}, "constructron_pathing_dummy" , next_station.position)
            end
            job.start_tick = game.tick
            debug_lib.DebugLog('request_items action timed out, moving to new station')
        end
    else
        return true
    end
end

-------------------------------------------------------------------------------
--  Actions
-------------------------------------------------------------------------------

me.actions = {
    go_to_position = function(constructrons, position, find_path)
        debug_lib.DebugLog('ACTION: go_to_position')
        if find_path then
            return me.pathfinder.request_path(constructrons, "constructron_pathing_dummy" , position)
        else
            for c, constructron in ipairs(constructrons) do
                constructron.autopilot_destination = position -- does not use path finder!
            end
        end
        for c, constructron in ipairs(constructrons) do
            me.set_constructron_status(constructron, 'on_transit', true)
        end
    end,
    build = function(constructrons)
        debug_lib.DebugLog('ACTION: build')
        -- I want to enable construction only when in the construction area
        -- however there doesn't seem to be a way to do this with the current api
        -- enable_logistic_while_moving is doing somewhat what I want however I wish there was a way to check
        -- whether or not logistics was enabled. there doesn't seem to be a way.
        -- so I'm counting on robots that they will be triggered in two second or 120 ticks.
        if constructrons[1].valid then
            for c, constructron in ipairs(constructrons) do
                constructron.enable_logistics_while_moving = false
                me.set_constructron_status(constructron, 'build_tick', game.tick)
            end
        else
            return true
        end
        -- enable construct
    end,
    deconstruct = function(constructrons)
        debug_lib.DebugLog('ACTION: deconstruct')
        -- I want to enable construction only when in the construction area
        -- however there doesn't seem to be a way to do this with the current api
        -- enable_logistic_while_moving is doing somewhat what I want however I wish there was a way to check
        -- whether or not logistics was enabled. there doesn't seem to be a way.
        -- so I'm counting on robots that they will be triggered in two second or 120 ticks.
        for c, constructron in ipairs(constructrons) do
            if constructron.valid then
                constructron.enable_logistics_while_moving = false
                me.set_constructron_status(constructron, 'deconstruct_tick', game.tick)
            else
                return true
            end
        end
        -- enable construct
    end,
    request_items = function(constructrons, items)
        debug_lib.DebugLog('ACTION: request_items')
        local closest_station = me.get_closest_service_station(constructrons[1]) -- they must go to the same station even if they are not in the same station.
        for c, constructron in ipairs(constructrons) do
            me.pathfinder.request_path({constructron}, "constructron_pathing_dummy" , closest_station.position)
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
        debug_lib.DebugLog('ACTION: clear_items')
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
                                    name = item.name,
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
                return true
            end
        end
    end,
    retire = function(constructrons)
        debug_lib.DebugLog('ACTION: retire')
        for c, constructron in ipairs(constructrons) do
            if constructron.valid then
                me.set_constructron_status(constructron, 'busy', false)
                me.paint_constructron(constructron, 'idle')
            end
        end
    end,
    add_to_check_chunk_done_queue = function(_, chunk)
        debug_lib.DebugLog('ACTION: add_to_check_chunk_done_queue')
        local entity_names = {}
        for name, _ in pairs(chunk.required_items) do
            table.insert(entity_names, name)
        end
        local surface = game.surfaces[chunk.surface]
        debug_lib.draw_rectangle(chunk.minimum, chunk.maximum, surface, color_lib.color_alpha(color_lib.colors.blue, 0.5))

        local ghosts = surface.find_entities_filtered {
            area = {chunk.minimum, chunk.maximum},
            type = {"entity-ghost", "tile-ghost", "item-request-proxy"}
        } or {}
        if next(ghosts) then -- if there are ghosts because inventory doesn't have the items for them, add them to be built for the next job
            game.print('added ' .. #ghosts .. ' unbuilt ghosts.')

            for i, entity in ipairs(ghosts) do
                local ghost_count = global.ghost_entities_count
                ghost_count = ghost_count + 1
                global.ghost_entities_count = ghost_count
                global.ghost_entities[ghost_count] = entity
            end
        end
    end,
    check_decon_chunk = function(_, chunk)
        debug_lib.DebugLog('ACTION: check_decon_chunk')
        local entity_names = {}
        for name, _ in pairs(chunk.required_items) do
            table.insert(entity_names, name)
        end
        local surface = game.surfaces[chunk.surface]
        debug_lib.draw_rectangle(chunk.minimum, chunk.maximum, surface, color_lib.color_alpha(color_lib.colors.red, 0.5))

        local decons = surface.find_entities_filtered {
            area = {chunk.minimum, chunk.maximum},
            to_be_deconstructed = true,
            ghost_name = entity_names
        } or {}
        if next(decons) then -- if there are ghosts because inventory doesn't have the items for them, add them to be built for the next job
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

-------------------------------------------------------------------------------
--  Conditions
-------------------------------------------------------------------------------

me.conditions = {
    position_done = function(constructrons, position) -- this is condition for action "go_to_position"
        debug_lib.VisualDebugText("Moving to position", constructrons[1])
        for c, constructron in ipairs(constructrons) do
            if (constructron.valid == false) then
                return true
            end
            if (chunk_util.distance_between(constructron.position, position) > 5) then -- or not me.robots_inactive(constructron) then
                return false
            end
        end
        return true
    end,
    build_done = function(constructrons, _, _, _)
        debug_lib.VisualDebugText("Constructing", constructrons[1])
        if constructrons[1].valid then
            for c, constructron in ipairs(constructrons) do
                local bots_inactive = me.robots_inactive(constructron)
                if not bots_inactive then
                    return false
                end
            end
            if (game.tick - (me.get_constructron_status(constructrons[1], 'build_tick'))) > 120 then
                return true
            end
        else
            return true
        end
    end,
    deconstruction_done = function(constructrons)
        debug_lib.VisualDebugText("Deconstructing", constructrons[1])
        if constructrons[1].valid then
            for c, constructron in ipairs(constructrons) do
                if not me.robots_inactive(constructron) then
                    return false
                end
            end
            if game.tick - me.get_constructron_status(constructrons[1], 'deconstruct_tick') > 120 then
                return true
            end
        else
            return true
        end
    end,
    request_done = function(constructrons)
        debug_lib.VisualDebugText("Processing logistics", constructrons[1])
        if me.constructrons_need_reload(constructrons) then
            return false
        else
            for c, constructron in ipairs(constructrons) do
                if constructron.valid then
                    for i = 1, constructron.request_slot_count do
                        constructron.clear_vehicle_logistic_slot(i)
                    end
                else
                    return true
                end
            end
        end
        return true
    end,
    pass = function(_)
        return true
    end
}

me.create_job = function(job_bundle_index, job)
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

me.setup_constructrons = function()
    for _, constructron in pairs(global.constructrons) do
        debug_lib.VisualDebugText("Checking Constructron", constructron)
        local desired_robot_count = settings.global["desired_robot_count"].value
        if not me.get_constructron_status(constructron, 'busy') then
            if not constructron.logistic_cell then
                debug_lib.VisualDebugText("Needs Equipment", constructron)
            else
                constructron.color = color_lib.color_alpha(color_lib.colors.white, 0.25)
                if (constructron.logistic_network.all_construction_robots < desired_robot_count) and (constructron.autopilot_destination == nil) then
                    debug_lib.DebugLog('ACTION: Stage')
                    local desired_robot_name = settings.global["desired_robot_name"].value
                    if game.item_prototypes[desired_robot_name] then
                        if global.stations_count[constructron.surface.index] > 0 then
                            debug_lib.VisualDebugText("Requesting Construction Robots", constructron)
                            constructron.enable_logistics_while_moving = false
                            -- they must go to the same station even if they are not in the same station.
                            -- they can be elsewhere though. they don't have to start in the same place.
                            -- This needs fixing: It is possible that not every ctron can reach the same station on a surface (example: two islands)
                            local closest_station = me.get_closest_service_station(constructron)
                            me.pathfinder.request_path({constructron}, "constructron_pathing_dummy" , closest_station.position)
                            local slot = 1
                            constructron.set_vehicle_logistic_slot(slot, {
                                name = desired_robot_name,
                                min = desired_robot_count,
                                max = desired_robot_count
                            })
                        end
                    else
                        debug_lib.DebugLog('desired_robot_name name is not valid in mod settings')
                    end
                end
            end
        end
    end
end

-- This function is a Mess: refactor - carefull, recursion!!!
me.get_chunks_and_constructrons = function(queued_chunks, preselected_constructrons, max_constructron)
    local inventory = preselected_constructrons[1].get_inventory(defines.inventory.spider_trunk) -- only checking if things can fit in the first constructron. expecting others to be the exact same.
    local empty_stack_count = inventory.count_empty_stacks()
    local function get_job_chunks_and_constructrons(chunks, constructron_count, total_required_slots, requested_items)
        local merged_chunk
        for i, chunk1 in ipairs(chunks) do
            for j, chunk2 in ipairs(chunks) do
                if not (i == j) then
                    local merged_area = chunk_util.merge_direct_neighbour(chunk1.area, chunk2.area)
                    if merged_area then
                        local required_slots1 = 0
                        local required_slots2 = 0
                        if not chunk1.merged then
                            required_slots1 = me.calculate_required_inventory_slot_count(chunk1.required_items or {}, constructron_count)
                            required_slots1 = required_slots1 + me.calculate_required_inventory_slot_count(chunk1.trash_items or {}, constructron_count)
                            for name, count in pairs(chunk1['required_items']) do
                                requested_items[name] = math.ceil(((requested_items[name] or 0) * constructron_count + count) / constructron_count)
                            end
                        end
                        if not chunk2.merged then
                            required_slots2 = me.calculate_required_inventory_slot_count(chunk2.required_items or {}, constructron_count)
                            required_slots2 = required_slots2 + me.calculate_required_inventory_slot_count(chunk2.trash_items or {}, constructron_count)
                            for name, count in pairs(chunk2['required_items']) do
                                requested_items[name] = math.ceil(((requested_items[name] or 0) * constructron_count + count) / constructron_count)
                            end
                        end
                        if ((total_required_slots + required_slots1 + required_slots2) < empty_stack_count) then
                            total_required_slots = total_required_slots + required_slots1 + required_slots2
                            merged_chunk = chunk_util.merge_neighbour_chunks(merged_area, chunk1, chunk2)
                            merged_chunk.merged = true

                            -- create a new table for remaining chunks
                            local remaining_chunks = {}
                            table.insert(remaining_chunks, merged_chunk)
                            for k, chunk in ipairs(chunks) do
                                if (not (k == i)) and (not (k == j)) then
                                    table.insert(remaining_chunks, chunk)
                                end
                            end
                            -- !!! recursive call
                            return get_job_chunks_and_constructrons(remaining_chunks, constructron_count, total_required_slots, requested_items)
                        elseif constructron_count < max_constructron and constructron_count < #preselected_constructrons then
                            -- use the original chunks and empty merge_chunks and start over
                            -- !!! recursive call
                            return get_job_chunks_and_constructrons(queued_chunks, constructron_count + 1, 0, {})
                        end
                    end
                end
            end
        end
        local my_constructrons = {}
        for c = 1, constructron_count do
            table.insert(my_constructrons, preselected_constructrons[c])
        end

        -- if the chunks didn't merge. there are unmerged chunks. they should be added as job if they can be.
        local unused_chunks = {}
        local used_chunks = {}
        requested_items = {}
        total_required_slots = 0

        for i, chunk in ipairs(chunks) do
            local required_slots = me.calculate_required_inventory_slot_count(chunk.required_items or {}, constructron_count)
            required_slots = required_slots + me.calculate_required_inventory_slot_count(chunk.trash_items or {}, constructron_count)
            if ((total_required_slots + required_slots) < empty_stack_count) then
                total_required_slots = total_required_slots + required_slots
                for name, count in pairs(chunk['required_items']) do
                    requested_items[name] = math.ceil(((requested_items[name] or 0) * constructron_count + count) / constructron_count)
                end
                table.insert(used_chunks, chunk)
            else
                table.insert(unused_chunks, chunk)
            end
        end

        used_chunks.requested_items = requested_items
        return used_chunks, my_constructrons, unused_chunks
    end
    return get_job_chunks_and_constructrons(queued_chunks, 1, 0, {})
end

me.get_job = function(constructrons)
    local managed_surfaces = game.surfaces -- revisit as all surfaces are scanned, even ones without service stations or constructrons.
    for _, surface in pairs(managed_surfaces) do -- iterate each surface
        if (next(global.construct_queue[surface.index]) or next(global.deconstruct_queue[surface.index]) or next(global.upgrade_queue[surface.index]) or next(global.repair_queue[surface.index])) then -- this means they are processed as chunks or it's empty.
            local max_worker = settings.global['max-worker-per-job'].value
            local available_constructrons = {}
            local chunks = {}
            local job_type

            for _, constructron in pairs(constructrons) do
                if (constructron.surface.index == surface.index) and constructron.logistic_cell and (constructron.logistic_network.all_construction_robots > 0) and not me.get_constructron_status(constructron, 'busy') then
                    table.insert(available_constructrons, constructron)
                end
            end
            if #available_constructrons < 1 then
                return
            end

            if next(global.deconstruct_queue[surface.index]) then -- deconstruction have priority over construction.
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

            elseif next(global.repair_queue[surface.index]) then
                for key, chunk in pairs(global.repair_queue[surface.index]) do
                    table.insert(chunks, chunk)
                end
                job_type = 'repair'
            end

            if not next(chunks) then
                return
            end

            local combined_chunks, selected_constructrons, unused_chunks = me.get_chunks_and_constructrons(chunks, available_constructrons, max_worker)

            local queue
            if job_type == 'deconstruct' then
                queue = global.deconstruct_queue
            elseif job_type == 'construct' then
                queue = global.construct_queue
            elseif job_type == 'upgrade' then
                queue = global.upgrade_queue
            elseif job_type == 'repair' then
                queue = global.repair_queue
            end
            queue[surface.index] = {}
            for i, chunk in ipairs(unused_chunks) do
                queue[surface.index][chunk.key] = chunk
            end

            local request_items_job = {
                action = 'request_items',
                action_args = {combined_chunks.requested_items},
                leave_condition = 'request_done',
                constructrons = selected_constructrons,
                start_tick = game.tick,
                unused_stations = me.get_service_stations(selected_constructrons[1].surface.index)
            }

            global.job_bundle_index = (global.job_bundle_index or 0) + 1
            me.create_job(global.job_bundle_index, request_items_job)
            for i, chunk in ipairs(combined_chunks) do
                chunk['positions'] = chunk_util.calculate_construct_positions({chunk.minimum, chunk.maximum}, selected_constructrons[1].logistic_cell.construction_radius * 0.85) -- 15% tolerance
                chunk['surface'] = surface.index
                local find_path = false
                for p, position in ipairs(chunk.positions) do
                    if p == 1 then
                        find_path = true
                    end
                    me.create_job(global.job_bundle_index, {
                        action = 'go_to_position',
                        action_args = {position, find_path},
                        leave_condition = 'position_done',
                        leave_args = {position},
                        constructrons = selected_constructrons,
                        start_tick = game.tick
                    })
                    if not (job_type == 'deconstruct') then
                        me.create_job(global.job_bundle_index, {
                            action = 'build',
                            leave_condition = 'build_done',
                            leave_args = {chunk.required_items, chunk.minimum, chunk.maximum},
                            constructrons = selected_constructrons,
                            job_class = job_type
                        })
                        if (job_type == 'construct') then
                            for c, constructron in ipairs(selected_constructrons) do
                                me.paint_constructron(constructron, 'construct')
                            end
                        elseif (job_type == 'repair') then
                            for c, constructron in ipairs(selected_constructrons) do
                                me.paint_constructron(constructron, 'repair')
                            end
                        end
                    elseif (job_type == 'deconstruct') then
                        me.create_job(global.job_bundle_index, {
                            action = 'deconstruct',
                            leave_condition = 'deconstruction_done',
                            constructrons = selected_constructrons
                        })
                    end
                    for c, constructron in ipairs(selected_constructrons) do
                        me.paint_constructron(constructron, job_type)
                    end
                end
                if (job_type == 'construct') then
                    me.create_job(global.job_bundle_index, {
                        action = 'add_to_check_chunk_done_queue',
                        action_args = {chunk},
                        leave_condition = 'pass', -- there is no leave condition
                        constructrons = selected_constructrons
                    })
                end
                if (job_type == 'deconstruct') then
                    me.create_job(global.job_bundle_index, {
                        action = 'check_decon_chunk',
                        action_args = {chunk},
                        leave_condition = 'pass', -- there is no leave condition
                        constructrons = selected_constructrons
                    })
                end
            end
            -- go back to a service_station when job is done.
            local closest_station = me.get_closest_service_station(selected_constructrons[1])
            local home_position = closest_station.position
            me.create_job(global.job_bundle_index, {
                action = 'go_to_position',
                action_args = {home_position, true},
                leave_condition = 'position_done',
                leave_args = {home_position},
                constructrons = selected_constructrons,
                start_tick = game.tick
            })

            me.create_job(global.job_bundle_index, {
                action = 'clear_items',
                leave_condition = 'request_done',
                constructrons = selected_constructrons
            })
            me.create_job(global.job_bundle_index, {
                action = 'retire',
                leave_condition = 'pass',
                leave_args = {home_position},
                constructrons = selected_constructrons
            })
        end
    end
end

me.do_job = function(job_bundles)
    if not next(job_bundles) then
        return
    end

    for i, job_bundle in pairs(job_bundles) do
        local job = job_bundle[1]
        if job then
            for c, constructron in ipairs(job.constructrons) do
                if not job.active then
                    me.set_constructron_status(constructron, 'busy', true)
                end
            end
            if job.constructrons[1] then
                me.do_until_leave(job)
                job.active = true
            else
                return true
            end
        else
            job_bundles[i] = nil
        end
    end
end

me.process_job_queue = function(_)
    me.get_job(global.constructrons)
    me.do_job(global.job_bundles)
end

me.perform_surface_cleanup = function(_)
    debug_lib.DebugLog('Surface job cleanup')
    for s, surface in pairs(game.surfaces) do
        if not global.constructrons_count[surface.index] or not global.stations_count[surface.index] then
            global.constructrons_count[surface.index] = 0
            global.stations_count[surface.index] = 0
        end
        if (global.constructrons_count[surface.index] <= 0) or (global.stations_count[surface.index] <= 0) then
            debug_lib.DebugLog('No Constructrons or Service Stations found on ' .. surface.name .. '. All job queues cleared!')
            global.construct_queue[surface.index] = {}
            global.deconstruct_queue[surface.index] = {}
            global.upgrade_queue[surface.index] = {}
        end
    end
end

me.on_built_entity = function(event) -- for entity creation
    local function is_floor_tile(entity_name)
        local floor_tiles = {"landfill", "se-space-platform-scaffold", "se-space-platform-plating", "se-spaceship-floor"}
        -- ToDo:
        --  find landfill-like tiles based on collision layer
        --  this list should be build at loading time not everytime
        return custom_lib.table_has_value(floor_tiles, entity_name)
    end

    local entity = event.entity or event.created_entity
    if not entity then
        return
    end

    if entity.type == 'item-request-proxy' then
        global.ghost_entities[entity.unit_number] = entity
        global.ghost_tick = event.tick -- to look at later, updating a global each time a ghost is created, should this be per ghost?
    else
        if entity.type == 'entity-ghost' or entity.type == 'tile-ghost' then
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
                global.ghost_entities[entity.unit_number] = entity
                global.ghost_tick = event.tick -- to look at later, updating a global each time a ghost is created, should this be per ghost?
            end
        elseif entity.name == 'constructron' then
            local registration_number = script.register_on_entity_destroyed(entity)

            me.paint_constructron(entity, 'idle')
            entity.enable_logistics_while_moving = false
            global.constructrons[entity.unit_number] = entity
            global.registered_entities[registration_number] = {
                name = "constructron",
                surface = entity.surface.index
            }
            global.constructrons_count[entity.surface.index] = global.constructrons_count[entity.surface.index] + 1
        elseif entity.name == "service_station" then
            local registration_number = script.register_on_entity_destroyed(entity)

            global.service_stations[entity.unit_number] = entity
            global.registered_entities[registration_number] = {
                name = "service_station",
                surface = entity.surface.index
            }
            global.stations_count[entity.surface.index] = global.stations_count[entity.surface.index] + 1
        end
    end
end

me.on_entity_damaged = function(event)
    local entity = event.entity
    if ((event.final_health / entity.prototype.max_health) * 100) < settings.global["repair_percent"].value then
        if not global.repair_entities[entity.unit_number] then
            global.repair_marked_tick = event.tick
            global.repair_entities[entity.unit_number] = entity
        end
    elseif global.repair_entities[entity.unit_number] and event.final_health == 0 then
        global.repair_entities[entity.unit_number] = nil
    end
end

me.on_post_entity_died = function(event) -- for entities that die and need rebuilding
    local entity = event.ghost
    if entity and entity.type == 'entity-ghost' then
        global.ghost_entities[entity.unit_number] = entity
        global.ghost_tick = event.tick
    end
end

me.on_marked_for_upgrade = function(event) -- for entity upgrade
    global.upgrade_marked_tick = event.tick
    global.upgrade_entities[event.entity.unit_number] = {
        entity = event.entity,
        target = event.target
    }
end

me.on_entity_marked_for_deconstruction = function(event) -- for entity deconstruction
    global.deconstruct_marked_tick = event.tick
    global.deconstruction_entities[event.entity.unit_number] = event.entity
end

me.on_surface_created = function(event)
    local index = event.surface_index

    global.construct_queue[index] = {}
    global.deconstruct_queue[index] = {}
    global.upgrade_queue[index] = {}
    global.repair_queue[index] = {}

    global.constructrons_count[index] = 0
    global.stations_count[index] = 0
end

me.on_surface_deleted = function(event)
    local index = event.surface_index

    global.construct_queue[index] = nil
    global.deconstruct_queue[index] = nil
    global.upgrade_queue[index] = nil
    global.repair_queue[index] = nil

    global.constructrons_count[index] = nil
    global.stations_count[index] = nil
end

me.on_entity_cloned = function(event)
    local entity = event.destination
    if entity.name == 'constructron' then
        local registration_number = script.register_on_entity_destroyed(entity)
        debug_lib.DebugLog('constructron ' .. event.destination.unit_number .. ' Cloned!')
        me.paint_constructron(entity, 'idle')

        global.constructrons[entity.unit_number] = entity
        global.registered_entities[registration_number] = {
            name = "constructron",
            surface = entity.surface.index
        }
        global.constructrons_count[entity.surface.index] = global.constructrons_count[entity.surface.index] + 1
    elseif entity.name == "service_station" then
        local registration_number = script.register_on_entity_destroyed(entity)
        debug_lib.DebugLog('service_station ' .. event.destination.unit_number .. ' Cloned!')

        global.service_stations[entity.unit_number] = entity
        global.registered_entities[registration_number] = {
            name = "service_station",
            surface = entity.surface.index
        }
        global.stations_count[entity.surface.index] = global.stations_count[entity.surface.index] + 1
    end
end

me.on_entity_destroyed = function(event)
    if global.registered_entities[event.registration_number] then
        local removed_entity = global.registered_entities[event.registration_number]
        if removed_entity.name == "constructron" then
            local surface = removed_entity.surface
            global.constructrons_count[surface] = math.max(0, global.constructrons_count[surface] - 1)
            global.constructrons[event.unit_number] = nil
            debug_lib.DebugLog('constructron ' .. event.unit_number .. ' Destroyed!')
        elseif removed_entity.name == "service_station" then
            local surface = removed_entity.surface
            global.stations_count[surface] = math.max(0, global.stations_count[surface] - 1)
            global.service_stations[event.unit_number] = nil
            debug_lib.DebugLog('service_station ' .. event.unit_number .. ' Destroyed!')
        end
        global.registered_entities[event.registration_number] = nil
    end
end

me.set_constructron_status = function(constructron, state, value)
    if constructron.valid then
        if global.constructron_statuses[constructron.unit_number] then
            global.constructron_statuses[constructron.unit_number][state] = value
        else
            global.constructron_statuses[constructron.unit_number] = {}
            global.constructron_statuses[constructron.unit_number][state] = value
        end
    else
        return true
    end
end

me.get_constructron_status = function(constructron, state)
    if constructron then
        if global.constructron_statuses[constructron.unit_number] then
            return global.constructron_statuses[constructron.unit_number][state]
        end
        return nil
    else
        return true
    end
end

me.get_closest_service_station = function(constructron)
    local service_stations = me.get_service_stations(constructron.surface.index)
    if service_stations then
        for unit_number, station in pairs(service_stations) do
            if not station.valid then
                global.service_stations[unit_number] = nil -- could be redundant as entities are now registered
            end
        end
        local service_station_index = chunk_util.get_closest_object(service_stations, constructron.position)
        return service_stations[service_station_index]
    end
end

me.get_closest_unused_service_station = function(constructron, unused_stations)
    if unused_stations then
        local unused_stations_index = chunk_util.get_closest_object(unused_stations, constructron.position)
        return unused_stations[unused_stations_index]
    end
end

me.paint_constructron = function(constructron, color_state)
    if color_state == 'idle' then
        constructron.color = color_lib.color_alpha(color_lib.colors.white, 0.25)
    elseif color_state == 'construct' then
        constructron.color = color_lib.color_alpha(color_lib.colors.blue, 0.4)
    elseif color_state == 'deconstruct' then
        constructron.color = color_lib.color_alpha(color_lib.colors.red, 0.4)
    elseif color_state == 'upgrade' then
        constructron.color = color_lib.color_alpha(color_lib.colors.green, 0.4)
    elseif color_state == 'repair' then
        constructron.color = color_lib.color_alpha(color_lib.colors.charcoal, 0.4)
    end
end

return me
