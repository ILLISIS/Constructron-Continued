local job = require("script/job")

-- sub class for deconstruction jobs
local deconstruction_job = setmetatable({}, job_metatable) ---@class deconstruction_job : job
local deconstruction_job_metatable = { __index = deconstruction_job } ---@type metatable
script.register_metatable("deconstruction_job_table", deconstruction_job_metatable)

function deconstruction_job.new(job_index, surface_index, job_type, worker)
    local self = job.new(job_index, surface_index, job_type, worker)
    setmetatable(self, deconstruction_job_metatable)
    return self
end

function deconstruction_job:specific_action()
    local worker = self.worker ---@cast worker -nil
    local entities = worker.surface.find_entities_filtered {
        position = worker.position,
        radius = self.worker_logistic_cell.construction_radius,
        to_be_deconstructed = true,
        force = {worker.force, "neutral"}
    } -- only detects entities in range
    local can_remove_entity = false
    for _, entity in pairs(entities) do
        if not (entity.type == "cliff") or self.worker_logistic_network.can_satisfy_request({name = "cliff-explosives", quality = "normal"}, 1, true) then
            can_remove_entity = true
            return
        end
    end
    if not can_remove_entity then
        table.remove(self.task_positions, 1)
    end
end

return deconstruction_job