
local debug_lib = require("script/debug_lib")
local chunk_util = require("script/chunk_util")
local color_lib = require("script/color_lib")
local pathfinder = require("script/pathfinder")

job_proc = {}

-------------------------------------------------------------------------------
--  Job processing
-------------------------------------------------------------------------------

job_proc.process_job_queue = function()
    job_proc.get_job()
    job_proc.do_job(global.job_bundles)
end

setup_job = function()
    for 

job_proc.get_job = function()
    local managed_surfaces = game.surfaces -- revisit as all surfaces are scanned, even ones without service stations or constructrons.
    for _, surface in pairs(managed_surfaces) do -- iterate each surface
        local surface_index = surface.index
        if (global.constructrons_count[surface_index] > 0) and (global.stations_count[surface_index] > 0) then
            if next(global.deconstruct_queue[surface_index]) or (next(global.construct_queue[surface_index]) or next(global.upgrade_queue[surface_index]) or next(global.repair_queue[surface_index])) then
                local chunks = {} --[=[@type Chunk[]]=]
                local job_type
                local chunk_counter = 0
                local worker = job_proc.get_worker(surface_index)
                if not (worker and worker.valid) then return end
                job_proc.set_constructron_status(worker, 'busy', true)
                if next(global.deconstruct_queue[surface_index]) then -- deconstruction have priority over construction.
                    for key, chunk in pairs(global.deconstruct_queue[surface_index]) do
                        chunk_counter = chunk_counter + 1
                        chunks[chunk_counter] = chunk
                    end
                    job_type = 'deconstruct'
                elseif next(global.construct_queue[surface_index]) then
                    for key, chunk in pairs(global.construct_queue[surface_index]) do
                        chunk_counter = chunk_counter + 1
                        chunks[chunk_counter] = chunk
                    end
                    job_type = 'construct'
                elseif next(global.upgrade_queue[surface_index]) then
                    for key, chunk in pairs(global.upgrade_queue[surface_index]) do
                        chunk_counter = chunk_counter + 1
                        chunks[chunk_counter] = chunk
                    end
                    job_type = 'upgrade'
                elseif next(global.repair_queue[surface_index]) then
                    for key, chunk in pairs(global.repair_queue[surface_index]) do
                        chunk_counter = chunk_counter + 1
                        chunks[chunk_counter] = chunk
                    end
                    job_type = 'repair'
                end
                ---@cast job_type JobType
                if not next(chunks) then
                    return
                end
                local combined_chunks, unused_chunks = me.get_chunks_and_constructrons(chunks, worker)
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
                queue[surface_index] = {}
                for i, chunk in ipairs(unused_chunks) do -- requeue unused chunks
                    queue[surface_index][chunk.key] = chunk
                end
                me.paint_constructron(worker, job_type)
                global.job_bundle_index = (global.job_bundle_index or 0) + 1
                local closest_station = me.get_closest_service_station(worker)
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
                    unused_stations = me.get_service_stations(worker.surface_index)
                })
                for i, chunk in ipairs(combined_chunks) do
                    chunk['positions'] = chunk_util.calculate_construct_positions({chunk.minimum, chunk.maximum}, worker.logistic_cell.construction_radius * 0.95) -- 5% tolerance
                    chunk['surface'] = surface_index
                    for p, position in ipairs(chunk.positions) do
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
                                    constructron = worker,
                                    job_class = job_type
                                })
                            else
                                job_proc.create_job(global.job_bundle_index, {
                                    action = 'build',
                                    leave_condition = 'upgrade_done',
                                    leave_args = {},
                                    constructron = worker,
                                    job_class = job_type
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
                me.do_until_leave(job)
            else -- cleanup job, check chunks and reprocess entities
                for _, value in pairs(global.job_bundles[job.bundle_index]) do  -- do check actions
                    if (value.action == "check_build_chunk") or (value.action == "check_decon_chunk") or (value.action == "check_upgrade_chunk") then
                        me.actions[value.action](value, table.unpack(value.action_args or {}))
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

job_proc.get_worker = function(surface_index)
    for _, constructron in pairs(global.constructrons) do
        if constructron and constructron.valid and (constructron.surface.index == surface_index) and not job_proc.get_constructron_status(constructron, 'busy') then
            if not constructron.logistic_cell then
                debug_lib.VisualDebugText("Needs Equipment", constructron, 0.4, 3)
            else
                local desired_robot_count = global.desired_robot_count
                local logistic_network = constructron.logistic_cell.logistic_network
                if ((logistic_network.all_construction_robots >= desired_robot_count) and not (ctron.robots_active(logistic_network))) or global.clear_robots_when_idle then
                    return constructron
                else
                    if not global.clear_robots_when_idle then
                        if global.stations_count[constructron.surface.index] > 0 then
                            debug_lib.DebugLog('ACTION: Stage')
                            local desired_robot_name = global.desired_robot_name

                            ---@cast desired_robot_name string
                            ---@cast desired_robot_count uint
                            if game.item_prototypes[desired_robot_name] then
                                if global.stations_count[constructron.surface.index] > 0 then
                                    debug_lib.VisualDebugText("Requesting Construction Robots", constructron, 0.4, 3)
                                    constructron.set_vehicle_logistic_slot(1, {
                                        name = desired_robot_name,
                                        min = desired_robot_count,
                                        max = desired_robot_count
                                    })
                                    local closest_station = me.get_closest_service_station(constructron)
                                    local distance = chunk_util.distance_between(constructron.position, closest_station.position)
                                    if distance < 9 then return end
                                    job_proc.set_constructron_status(constructron, 'busy', true)
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
                                    debug_lib.VisualDebugText("No Stations", constructron, 0.4, 3)
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
end

return job_proc
