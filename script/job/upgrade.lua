local job = require("script/job")

-- sub class for upgrade jobs
local upgrade_job = setmetatable({}, job_metatable) ---@class upgrade_job : job
local upgrade_job_metatable = { __index = upgrade_job } ---@type metatable
script.register_metatable("upgrade_job_table", upgrade_job_metatable)

function upgrade_job.new(job_index, surface_index, job_type, worker)
    local self = job.new(job_index, surface_index, job_type, worker)
    setmetatable(self, upgrade_job_metatable)
    return self
end

function upgrade_job:specific_action()
    local worker = self.worker ---@cast worker -nil
    local entities = worker.surface.find_entities_filtered {
        position = worker.position,
        radius = self.worker_logistic_cell.construction_radius,
        to_be_upgraded = true,
        force = worker.force.name
    } -- only detects entities in range
    local can_upgrade_entity = false
    for _, entity in pairs(entities) do
        local target, target_quality = entity.get_upgrade_target() ---@cast target -nil
        local item_name = target.items_to_place_this[1].name
        if self.worker_logistic_network.can_satisfy_request({name = item_name, quality = target_quality}, 1, false) then -- does inventory have the required item?
            can_upgrade_entity = true
        end
    end
    if not can_upgrade_entity then
        table.remove(self.task_positions, 1)
    end
end

return upgrade_job