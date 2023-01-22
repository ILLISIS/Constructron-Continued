
local debug_lib = require("script/debug_lib")
local chunk_util = require("script/chunk_util")
local color_lib = require("script/color_lib")
local ctron = require("script/constructron")

local job_proc = {}

-------------------------------------------------------------------------------
--  Job processing
-------------------------------------------------------------------------------

job_proc.process_job_queue = function()
    job_proc.get_job() -- job creation
    job_proc.do_job(global.job_bundles) -- job opteration
end

job_proc.get_job = function()
    for _, surface in pairs(game.surfaces) do -- iterate each surface
        local surface_index = surface.index
        if (global.constructrons_count[surface_index] > 0) and (global.stations_count[surface_index] > 0) then
            local job_type
            if next(global.deconstruct_queue[surface_index]) then -- deconstruction has priority over construction.
                job_type = 'deconstruct'
            elseif next(global.construct_queue[surface_index]) then
                job_type = 'construct'
            elseif next(global.upgrade_queue[surface_index]) then
                job_type = 'upgrade'
            elseif next(global.repair_queue[surface_index]) then
                job_type = 'repair'
            end
            if (job_type ~= nil) then
                -- get a constructron for this job
                local worker = job_proc.get_worker(surface_index)
                if not (worker and worker.valid) then return end
                ctron.set_constructron_status(worker, 'busy', true)
                ctron.paint_constructron(worker, job_type)
                local inventory = worker.get_inventory(defines.inventory.spider_trunk)
                local empty_stack_count = ((inventory.count_empty_stacks()) - (job_proc.calculate_required_inventory_slot_count({[global.desired_robot_name] = global.desired_robot_count})))
                -- merge chunks in proximity to each other
                local requested_items = {}
                local total_required_stacks = 0
                local combined_chunks = job_proc.merge_chunks(global[job_type .. "_queue"][surface_index], total_required_stacks, empty_stack_count, requested_items, job_type, surface_index)
                -- get closest service station
                global.job_bundle_index = (global.job_bundle_index or 0) + 1
                local closest_station = ctron.get_closest_service_station(worker)
                -- go to service station
                job_proc.create_job(global.job_bundle_index, {
                    action = 'go_to_position',
                    action_args = {closest_station.position},
                    leave_condition = 'position_done',
                    leave_args = {closest_station.position},
                    constructron = worker
                })
                -- request items
                job_proc.create_job(global.job_bundle_index, {
                    action = 'request_items',
                    action_args = {combined_chunks.requested_items},
                    leave_condition = 'request_done',
                    constructron = worker,
                    unused_stations = ctron.get_service_stations(worker.surface.index)
                })
                -- main job setup
                for _, chunk in ipairs(combined_chunks) do
                    debug_lib.draw_rectangle(chunk.minimum, chunk.maximum, surface, "yellow", false, 3600)
                    chunk['positions'] = chunk_util.calculate_construct_positions({chunk.minimum, chunk.maximum}, worker.logistic_cell.construction_radius * 0.95) -- 5% tolerance
                    chunk['surface'] = surface_index
                    for _, position in ipairs(chunk.positions) do
                        debug_lib.VisualDebugCircle(position, surface, "yellow", 0.5, 3600)
                        local landfill_check = false
                        if combined_chunks.requested_items["landfill"] then
                            landfill_check = true
                        end
                        -- move to position
                        job_proc.create_job(global.job_bundle_index, {
                            action = 'go_to_position',
                            action_args = {position},
                            leave_condition = 'position_done',
                            leave_args = {position},
                            constructron = worker,
                            landfill_job = landfill_check
                        })
                        -- do actions
                        if not (job_type == 'deconstruct') then
                            if not (job_type == 'upgrade') then
                                job_proc.create_job(global.job_bundle_index, {
                                    action = 'build',
                                    leave_condition = 'build_done',
                                    leave_args = {},
                                    constructron = worker
                                })
                            else
                                job_proc.create_job(global.job_bundle_index, {
                                    action = 'build',
                                    leave_condition = 'upgrade_done',
                                    leave_args = {},
                                    constructron = worker
                                })
                            end
                        elseif (job_type == 'deconstruct') then
                            job_proc.create_job(global.job_bundle_index, {
                                action = 'deconstruct',
                                leave_condition = 'deconstruction_done',
                                constructron = worker
                            })
                        end
                    end
                    if (job_type == 'construct') then
                        job_proc.create_job(global.job_bundle_index, {
                            action = 'check_build_chunk',
                            action_args = {chunk},
                            leave_condition = 'pass', -- there is no leave condition
                            constructron = worker
                        })
                    end
                    if (job_type == 'deconstruct') then
                        job_proc.create_job(global.job_bundle_index, {
                            action = 'check_decon_chunk',
                            action_args = {chunk},
                            leave_condition = 'pass', -- there is no leave condition
                            constructron = worker
                        })
                    end
                    if (job_type == 'upgrade') then
                        job_proc.create_job(global.job_bundle_index, {
                            action = 'check_upgrade_chunk',
                            action_args = {chunk},
                            leave_condition = 'pass', -- there is no leave condition
                            constructron = worker
                        })
                    end
                end
                -- go back to a service_station when job is done.
                job_proc.create_job(global.job_bundle_index, {
                    action = 'go_to_position',
                    action_args = {closest_station.position},
                    leave_condition = 'position_done',
                    leave_args = {closest_station.position},
                    constructron = worker,
                    returning_home = true
                })
                -- clear items
                job_proc.create_job(global.job_bundle_index, {
                    action = 'clear_items',
                    leave_condition = 'request_done',
                    constructron = worker
                })
                -- ready for next job
                job_proc.create_job(global.job_bundle_index, {
                    action = 'retire',
                    leave_condition = 'pass',
                    leave_args = {closest_station.position},
                    constructron = worker
                })
            end
        end
    end
end

---@param job_bundles JobBundle
job_proc.do_job = function(job_bundles)
    if not next(job_bundles) then return end
    for i, job_bundle in pairs(job_bundles) do
        local job = job_bundle[1]
        if job then
            if job.constructron and job.constructron and job.constructron.valid then
                if not job.active then
                    job.attempt = 0
                    job.active = true
                    job.start_tick = game.tick
                    ctron.actions[job.action](job, table.unpack(job.action_args or {}))
                end
                local status = ctron.conditions[job.leave_condition](job, table.unpack(job.leave_args or {}))
                if status == true then -- true means you can remove this job from job list
                    table.remove(global.job_bundles[job.bundle_index], 1)
                end
            else -- cleanup job, check chunks and reprocess entities
                for _, value in pairs(global.job_bundles[job.bundle_index]) do  -- do check actions
                    if (value.action == "check_build_chunk") or (value.action == "check_decon_chunk") or (value.action == "check_upgrade_chunk") then
                        ctron.actions[value.action](value, table.unpack(value.action_args or {}))
                    end
                end
                job_bundles[i] = nil -- remove job
            end
        else
            job_bundles[i] = nil
        end
    end
end

-------------------------------------------------------------------------------
--  Utility
-------------------------------------------------------------------------------

---@param surface_index uint
---@return LuaEntity?
job_proc.get_worker = function(surface_index)
    for _, constructron in pairs(global.constructrons) do
        if constructron and constructron.valid and (constructron.surface.index == surface_index) and not ctron.get_constructron_status(constructron, 'busy') then
            if not constructron.logistic_cell or not ((constructron.grid.generator_energy > 0) or (constructron.grid.max_solar_energy > 0)) then
                rendering.draw_text {
                    text = "Needs Equipment",
                    target = constructron,
                    filled = true,
                    surface = constructron.surface,
                    time_to_live = 180,
                    target_offset = {0, -1},
                    alignment = "center",
                    color = {r = 255, g = 255, b = 255, a = 255}
                }
            else
                local desired_robot_count = global.desired_robot_count
                local logistic_network = constructron.logistic_cell.logistic_network
                if ((logistic_network.all_construction_robots >= desired_robot_count) and not next(logistic_network.construction_robots)) or global.clear_robots_when_idle then
                    return constructron
                else
                    if not global.clear_robots_when_idle then
                        local desired_robot_name = global.desired_robot_name
                        ---@cast desired_robot_name string
                        ---@cast desired_robot_count uint
                        if game.item_prototypes[desired_robot_name] then
                            debug_lib.VisualDebugText("Requesting Construction Robots", constructron, -1, 3)
                            constructron.set_vehicle_logistic_slot(1, {
                                name = desired_robot_name,
                                min = desired_robot_count,
                                max = desired_robot_count
                            })
                            local closest_station = ctron.get_closest_service_station(constructron)
                            local distance = chunk_util.distance_between(constructron.position, closest_station.position)
                            if distance < 9 then return end
                            ctron.set_constructron_status(constructron, 'busy', true)
                            global.job_bundle_index = (global.job_bundle_index or 0) + 1
                            job_proc.create_job(global.job_bundle_index, {
                                action = 'go_to_position',
                                action_args = {closest_station.position},
                                leave_condition = 'position_done',
                                leave_args = {closest_station.position},
                                constructron = constructron
                            })
                            job_proc.create_job(global.job_bundle_index, {
                                action = 'retire',
                                leave_condition = 'pass',
                                leave_args = {closest_station.position},
                                constructron = constructron
                            })
                        else
                            debug_lib.DebugLog('desired_robot_name name is not valid in mod settings')
                        end
                    end
                end
            end
        end
    end
end

---@param chunks Chunk
---@param total_required_stacks integer
---@param empty_stack_count integer
---@param requested_items table
---@param job_type string
---@param surface_index integer
---@return Chunk[]
job_proc.merge_chunks = function(chunks, total_required_stacks, empty_stack_count, requested_items, job_type, surface_index)
    local merged_chunk
    for i, chunk1 in pairs(chunks) do -- first chunk
        for j, chunk2 in pairs(chunks) do -- compared chunk
            if not (i == j) then -- if not self
                local merged_area = chunk_util.check_if_neighbour(chunk1.area, chunk2.area) -- checks if chunks are near to each other
                if merged_area then -- chunks are neighbors
                    local required_slots1 = 0
                    local required_slots2 = 0
                    if not chunk1.merged then
                        required_slots1 = job_proc.calculate_required_inventory_slot_count(chunk1.required_items or {})
                        required_slots1 = required_slots1 + job_proc.calculate_required_inventory_slot_count(chunk1.trash_items or {})
                        for name, count in pairs(chunk1['required_items']) do
                            requested_items[name] = math.ceil((requested_items[name] or 0) + count)
                        end
                    end
                    if not chunk2.merged then
                        required_slots2 = job_proc.calculate_required_inventory_slot_count(chunk2.required_items or {})
                        required_slots2 = required_slots2 + job_proc.calculate_required_inventory_slot_count(chunk2.trash_items or {})
                        for name, count in pairs(chunk2['required_items']) do
                            requested_items[name] = math.ceil((requested_items[name] or 0) + count)
                        end
                    end
                    if ((total_required_stacks + required_slots1 + required_slots2) < empty_stack_count) then -- actually merge the chunks if inventory fits
                        total_required_stacks = total_required_stacks + required_slots1 + required_slots2
                        merged_chunk = chunk_util.merge_neighbour_chunks(merged_area, chunk1, chunk2)
                        merged_chunk.merged = true
                        -- create a new table for remaining chunks
                        local remaining_chunks = {}
                        local remaining_counter = 1
                        remaining_chunks[1] = merged_chunk
                        for k, chunk in pairs(chunks) do
                            if (not (k == i)) and (not (k == j)) then
                                remaining_counter = remaining_counter + 1
                                remaining_chunks[remaining_counter] = chunk
                            end
                        end
                        -- !!! recursive call
                        return job_proc.merge_chunks(remaining_chunks, total_required_stacks, empty_stack_count, requested_items, job_type, surface_index)
                    end
                end
            end
        end
    end
    -- reaching this point of the function means that as many of the original set of chunks have been merged together as possible
    global[job_type .. "_queue"][surface_index] = {} -- clear the queue
    ---@type Chunk[]
    local used_chunks = {}
    local used_chunk_counter = 1
    ---@type ItemCounts
    requested_items = {}
    total_required_stacks = 0
    for i, chunk in pairs(chunks) do
        local divisor = 1
        local required_slots = job_proc.calculate_required_inventory_slot_count(chunk.required_items or {})
        required_slots = required_slots + job_proc.calculate_required_inventory_slot_count(chunk.trash_items or {})
        if ((total_required_stacks + required_slots) < empty_stack_count) then
            total_required_stacks = total_required_stacks + required_slots
            for name, count in pairs(chunk['required_items']) do
                requested_items[name] = math.ceil(((requested_items[name] or 0) + count))
            end
            used_chunks[used_chunk_counter] = chunk
            used_chunk_counter = used_chunk_counter + 1
            global[job_type .. "_queue"][surface_index][i] = nil
        else -- chunk will not fit into the inventory
            if required_slots > empty_stack_count then -- if chunk is overloaded
                divisor = math.ceil(required_slots / empty_stack_count)
                for item, count in pairs(chunk.required_items) do
                    chunk.required_items[item] = math.ceil(count / divisor)
                end
                for item, count in pairs(chunk.trash_items) do
                    chunk.trash_items[item] = math.ceil(count / divisor)
                end
                requested_items = chunk.required_items -- !! trash items just need to be divided
                used_chunks[used_chunk_counter] = chunk
                used_chunk_counter = used_chunk_counter + 1
            end
            if divisor > 1 then -- duplicate the chunk so another constructron will perform the same job
                for j = 1, (divisor - 1) do
                    global[job_type .. "_queue"][surface_index][i .. "-" .. j] = chunk
                end
            else
                global[job_type .. "_queue"][surface_index][i] = chunk
            end
        end
    end
    used_chunks.requested_items = requested_items
    return used_chunks -- these chunks will be used in the job
end

---@param job_bundle_index uint
---@param job Job
job_proc.create_job = function(job_bundle_index, job)
    if not global.job_bundles then
        global.job_bundles = {}
    end
    if not global.job_bundles[job_bundle_index] then
        global.job_bundles[job_bundle_index] = {}
    end
    local index = #global.job_bundles[job_bundle_index] + 1 --[[@as uint]]
    job.bundle_index = job_bundle_index
    global.job_bundles[job_bundle_index][index] = job
end

---@param required_items ItemCounts
---@return integer
job_proc.calculate_required_inventory_slot_count = function(required_items)
    local slots = 0
    local stack_size

    for name, count in pairs(required_items) do
        if not global.stack_cache[name] then
            stack_size = game.item_prototypes[name].stack_size
            global.stack_cache[name] = stack_size
        else
            stack_size = global.stack_cache[name]
        end
        slots = slots + math.ceil(count / stack_size)
    end
    return slots
end

return job_proc
