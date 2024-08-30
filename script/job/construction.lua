local job = require("script/job")


-- sub class for construction jobs
local construction_job = setmetatable({}, job_metatable) ---@class construction_job : job
local construction_job_metatable = { __index = construction_job } ---@type metatable
script.register_metatable("construction_job_table", construction_job_metatable)

function construction_job.new(job_index, surface_index, job_type, worker)
    local self = job.new(job_index, surface_index, job_type, worker)
    setmetatable(self, construction_job_metatable)
    return self
end

function construction_job:specific_action()
    local worker = self.worker ---@cast worker -nil
    local entities = worker.surface.find_entities_filtered {
        position = worker.position,
        radius = self.worker_logistic_cell.construction_radius,
        name = {"entity-ghost", "tile-ghost", "item-request-proxy"},
        force = worker.force
    } -- only detects entities in range
    local can_build_entity = false
    for _, entity in pairs(entities) do
        local item
        if entity.name == "entity-ghost" or entity.name == "tile-ghost" then -- is the entity a ghost?
            item = entity.ghost_prototype.items_to_place_this[1]
        else -- entity is an item_request_proxy
            item = {}
            for name, count in pairs(entity.item_requests) do
                item.name = name
                item.count = count
            end
        end
        if self.worker_logistic_network.can_satisfy_request(item.name, (item.count or 1)) then -- does inventory have the required item?
            can_build_entity = true
        end
    end
    if not can_build_entity then
        table.remove(self.task_positions, 1)
    end
end

return construction_job