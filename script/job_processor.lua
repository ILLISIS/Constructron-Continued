
local debug_lib = require("script/debug_lib")
local util_func = require("script/utility_functions")

local job = require("script/job")
local construction_job = require("script/job/construction")
local deconstruction_job = require("script/job/deconstruction")
local upgrade_job = require("script/job/upgrade")
local repair_job = require("script/job/repair")
local destroy_job = require("script/job/destroy")
local utility_job = require("script/job/utility")
local cargo_job = require("script/job/cargo")

local job_proc = {}

-------------------------------------------------------------------------------
--  Job processing
-------------------------------------------------------------------------------

job_proc.process_job_queue = function()
    -- job creation
    if global.queue_proc_trigger then  -- there is something to do start processing
        job_proc.make_jobs()
    end
    -- job operation
    if global.job_proc_trigger then
        for job_index, job in pairs(global.jobs) do
            job:execute(job_index)
        end
        if not next(global.jobs) then
            global.job_proc_trigger = false
        end
    end
end

-------------------------------------------------------------------------------
--  Utility
-------------------------------------------------------------------------------

job_proc.make_jobs = function()
    local trigger_skip = false
    local job_types = {
        ["deconstruction"] = deconstruction_job,
        ["construction"] = construction_job,
        ["upgrade"] = upgrade_job,
        ["repair"] = repair_job,
        ["destroy"] = destroy_job
    }

    -- for each surface
    for surface_index, _ in pairs(global.managed_surfaces) do
        local exitloop
        -- for each queue
        for job_type, job_class in pairs(job_types) do
            while next(global[job_type .. '_queue'][surface_index]) and (exitloop == nil) do
                if global.horde_mode then
                    for _, _ in pairs(global[job_type .. '_queue'][surface_index]) do
                        local worker = job.get_worker(surface_index)
                        if not (worker and worker.valid) then
                            trigger_skip = true
                            exitloop = true
                            break
                        end
                        global.job_index = global.job_index + 1
                        global.jobs[global.job_index] = job_class.new(global.job_index, surface_index, job_type, worker)
                        -- add robots to job
                        global.jobs[global.job_index].required_items = {[global.desired_robot_name[surface_index]] = global.desired_robot_count[surface_index]}
                        global.jobs[global.job_index]:get_chunk()
                        global.job_proc_trigger = true -- start job operations
                    end
                else
                    local worker = job.get_worker(surface_index)
                    if not (worker and worker.valid) then
                        trigger_skip = true
                        break
                    end
                    global.job_index = global.job_index + 1
                    global.jobs[global.job_index] = job_class.new(global.job_index, surface_index, job_type, worker)
                    -- add robots to job
                    global.jobs[global.job_index].required_items = {[global.desired_robot_name[surface_index]] = global.desired_robot_count[surface_index]}
                    global.jobs[global.job_index]:get_chunk()
                    global.jobs[global.job_index]:find_chunks_in_proximity()
                    global.job_proc_trigger = true -- start job operations
                end
            end
        end
    end
    if not trigger_skip then
        global.queue_proc_trigger = false -- stop queue processing
    end
end

return job_proc
