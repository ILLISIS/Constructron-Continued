
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
    job_proc.make_jobs()
    -- job operation
    for job_index, job in pairs(storage.jobs) do
        job:execute(job_index)
    end
end

-------------------------------------------------------------------------------
--  Utility
-------------------------------------------------------------------------------

job_proc.make_jobs = function()
    for surface_index, _ in pairs(storage.managed_surfaces) do
        job_proc.process_queues(surface_index)
    end
end

local job_types = {
    ["deconstruction"] = deconstruction_job,
    ["construction"] = construction_job,
    ["upgrade"] = upgrade_job,
    ["repair"] = repair_job,
    ["destroy"] = destroy_job
}

job_proc.process_queues = function(surface_index)
    if not (storage.available_ctron_count[surface_index] > 0) then return end
    for job_type, job_class in pairs(job_types) do
        job_proc.process_queue(surface_index, job_type, job_class)
    end
end

job_proc.process_queue = function(surface_index, job_type, job_class)
    local job_start_delay = storage.job_start_delay
    for _, chunk in pairs(storage[job_type .. '_queue'][surface_index]) do
        if ((game.tick - chunk.last_update_tick) > job_start_delay) then
            local worker = job.get_worker(surface_index)
            if not (worker and worker.valid) then break end
            storage.job_index = storage.job_index + 1
            storage.jobs[storage.job_index] = job_class.new(storage.job_index, surface_index, job_type, worker)
            -- add robots to job
            local robot_item = storage.desired_robot_name[surface_index]
            storage.jobs[storage.job_index]["required_items"][robot_item.name] = {
                [robot_item.quality] = storage.desired_robot_count[surface_index]
            }
            storage.jobs[storage.job_index]:get_chunk()
            if not storage.horde_mode then
                storage.jobs[storage.job_index]:find_chunks_in_proximity()
            end
        end
    end
end

return job_proc
