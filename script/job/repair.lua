local job = require("script/job")

-- sub class for repair jobs
local repair_job = setmetatable({}, job_metatable) ---@class repair_job : job
local repair_job_metatable = { __index = repair_job } ---@type metatable
script.register_metatable("repair_job_table", repair_job_metatable)

function repair_job.new(job_index, surface_index, job_type, worker)
    local self = job.new(job_index, surface_index, job_type, worker)
    setmetatable(self, repair_job_metatable)
    return self
end

function repair_job:specific_action()
    if not self.repair_started then
        self.repair_started = true -- flag to ensure that at least 1 second passes before changing job state
        return
    end
    table.remove(self.task_positions, 1)
end

return repair_job