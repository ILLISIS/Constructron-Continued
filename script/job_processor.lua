
local debug_lib = require("script/debug_lib")
local chunk_util = require("script/chunk_util")
local ctron = require("script/constructron")

local job_proc = {}

-------------------------------------------------------------------------------
--  Job processing
-------------------------------------------------------------------------------

job_proc.process_job_queue = function()
    -- job creation
    if global.queue_proc_trigger then  -- there is something to do start processing
        for _, surface_index in pairs(global.managed_surfaces) do
            for i = 1, global.constructrons_count[surface_index] do
                job_proc.get_job(surface_index)
            end
        end
    end
    -- job operation
    if global.job_proc_trigger then
        job_proc.do_job(global.job_bundles)
    end
end

job_proc.get_job = function(surface_index)
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
    if (job_type == nil) then -- there is nothing to do pause processing
        global.queue_proc_trigger = false -- stop job processing
        return
    end
    -- get a constructron for this job
    local worker = job_proc.get_worker(surface_index)
    if not (worker and worker.valid) then return end
    global.job_proc_trigger = true -- start job operations
    ctron.set_constructron_status(worker, 'busy', true)
    ctron.paint_constructron(worker, job_type)
    local inventory = worker.get_inventory(defines.inventory.spider_trunk)
    -- calculate empty slots
    local empty_slots
    if game.item_prototypes[global.desired_robot_name] then
        empty_slots = ((inventory.count_empty_stacks()) - (job_proc.calculate_required_inventory_slot_count({[global.desired_robot_name] = global.desired_robot_count})))
    else
        empty_slots = inventory.count_empty_stacks()
    end
    -- merge chunks in proximity to each other into one job
    local chunk_params = {
        chunks = global[job_type .. "_queue"][surface_index],
        job_type = job_type,
        surface_index = surface_index,
        total_required_slots = 0,
        empty_slot_count = empty_slots,
        origin_chunk = nil,
        used_chunks = {},
        required_items = {}
    }
    local combined_chunks, required_items = job_proc.merge_chunks(chunk_params, nil)
    -- get closest service station
    global.job_bundle_index = (global.job_bundle_index or 0) + 1
    local closest_station = ctron.get_closest_service_station(worker)
    -- go to service station
    if next(required_items) or global.clear_robots_when_idle then
        local distance = chunk_util.distance_between(worker.position, closest_station.position)
        if distance > 10 then -- 10 is the logistic radius of a station
            job_proc.create_job(global.job_bundle_index, {
                action = 'go_to_position',
                action_args = {closest_station.position},
                leave_condition = 'position_done',
                leave_args = {closest_station.position},
                constructron = worker
            })
        end
        -- request items
        job_proc.create_job(global.job_bundle_index, {
            action = 'request_items',
            action_args = {required_items},
            leave_condition = 'request_done',
            constructron = worker,
            request_station = closest_station
        })
    end
    -- main job setup
    for _, chunk in ipairs(combined_chunks) do
        debug_lib.draw_rectangle(chunk.minimum, chunk.maximum, surface_index, "yellow", false, 3600)
        chunk['positions'] = chunk_util.calculate_construct_positions({chunk.minimum, chunk.maximum}, worker.logistic_cell.construction_radius * 0.95) -- 5% tolerance
        chunk['surface'] = surface_index
        for _, position in ipairs(chunk.positions) do
            debug_lib.VisualDebugCircle(position, surface_index, "yellow", 0.5, 3600)
            local landfill_check = false
            if required_items["landfill"] then
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
        leave_args = {},
        constructron = worker
    })
end

---@param job_bundles JobBundle
job_proc.do_job = function(job_bundles)
    if not next(job_bundles) then
        global.job_proc_trigger = false
    end
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
                local logistic_cell = constructron.logistic_cell
                local logistic_network = logistic_cell.logistic_network
                if ((logistic_network.all_construction_robots >= desired_robot_count) and not next(logistic_network.construction_robots)) or global.clear_robots_when_idle then
                    if logistic_cell.construction_radius > 0 then
                        return constructron
                    else
                        debug_lib.VisualDebugText("Unsuitable roboports!", constructron, -1, 3)
                        ctron.enable_roboports(constructron.grid) -- attempt to rectify issue
                    end
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
                            if distance > 9 then
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
                                global.job_proc_trigger = true -- start job operations
                            end
                        else
                            debug_lib.DebugLog('desired_robot_name name is not valid in mod settings')
                        end
                    end
                end
            end
        end
    end
end

---@param chunk_params table
---@param origin_chunk table
---@return Chunk[]
---@return required_items table
job_proc.merge_chunks = function(chunk_params, origin_chunk)
    for _, chunk in pairs(chunk_params.chunks) do
        if (chunk.midpoint == nil) then -- establish chunk
            chunk.midpoint = {x = ((chunk.minimum.x + chunk.maximum.x) / 2), y = ((chunk.minimum.y + chunk.maximum.y) / 2)}
            local required_slots = job_proc.calculate_required_inventory_slot_count(chunk.required_items or {})
            chunk.required_slots = required_slots + job_proc.calculate_required_inventory_slot_count(chunk.trash_items or {})
            if chunk.required_slots > chunk_params.empty_slot_count then -- if chunk is overloaded
                local divisor = math.ceil(chunk.required_slots / chunk_params.empty_slot_count)
                for item, count in pairs(chunk.required_items) do
                    chunk.required_items[item] = math.ceil(count / divisor)
                end
                for item, count in pairs(chunk.trash_items) do
                    chunk.trash_items[item] = math.ceil(count / divisor)
                end
                -- update required_slots
                required_slots = job_proc.calculate_required_inventory_slot_count(chunk.required_items or {})
                chunk.required_slots = required_slots + job_proc.calculate_required_inventory_slot_count(chunk.trash_items or {})
                -- duplicate the chunk so another constructron will perform the same job
                if divisor > 1 then
                    for i = 1, (divisor - 1) do
                        chunk_params.chunks[chunk.key .. "-" .. i] = table.deepcopy(chunk)
                        chunk_params.chunks[chunk.key .. "-" .. i].key = chunk.key .. "-" .. i
                    end
                end
            end
        end
        if (origin_chunk ~= nil) then
            if (chunk_util.distance_between(origin_chunk.midpoint, chunk.midpoint) < 160) then
                if ((chunk_params.total_required_slots + chunk.required_slots) < chunk_params.empty_slot_count) then
                    chunk_params.total_required_slots = chunk_params.total_required_slots + chunk.required_slots
                    table.insert(chunk_params.used_chunks, chunk)
                    for name, count in pairs(chunk['required_items']) do
                        chunk_params.required_items[name] = (chunk_params.required_items[name] or 0) + count
                    end
                    global[chunk_params.job_type .. "_queue"][chunk_params.surface_index][chunk.key] = nil
                    return job_proc.merge_chunks(chunk_params, chunk)
                end
            end
        else
            origin_chunk = chunk
            table.insert(chunk_params.used_chunks, chunk)
            chunk_params.total_required_slots = chunk.required_slots
            for name, count in pairs(chunk['required_items']) do
                chunk_params.required_items[name] = (chunk_params.required_items[name] or 0) + count
            end
            global[chunk_params.job_type .. "_queue"][chunk_params.surface_index][chunk.key] = nil
        end
    end
    return chunk_params.used_chunks, chunk_params.required_items
end

---@param job_bundle_index integer
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
