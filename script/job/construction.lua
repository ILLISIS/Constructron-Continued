local job = require("script/job")
local debug_lib = require("script/debug_lib")
local util_func = require("script/utility_functions")

-- sub class for construction jobs
local construction_job = setmetatable({}, job_metatable) ---@class construction_job : job
local construction_job_metatable = { __index = construction_job } ---@type metatable
script.register_metatable("construction_job_table", construction_job_metatable)

function construction_job.new(job_index, surface_index, job_type, worker)
    local self = job.new(job_index, surface_index, job_type, worker)
    setmetatable(self, construction_job_metatable)
    return self
end

-- this function checks if the worker is in the correct position
function construction_job:position_check(position, distance)
    local worker = self.worker ---@cast worker -nil
    local distance_from_pos = util_func.distance_between(worker.position, position)
    if distance_from_pos > distance then
        debug_lib.VisualDebugText({"ctron_status.moving_to_pos"}, worker, -1, 1)
        self.job_status = {"ctron_status.moving_to_pos"}
        if not worker.autopilot_destination then
            if not self.path_request_id then
                self:move_to_position(position)
            end
        else
            if self.landfill_job and self.state == "in_progress" and not self.worker_logistic_network.can_satisfy_request(self.landfill_type, 1) then -- is this a landfill job and do we have landfill?
                debug_lib.VisualDebugText({"ctron_status.no_landfill"}, worker, -0.5, 5)
                worker.autopilot_destination = nil
                self:check_chunks()
                self.state = "finishing"
                return false
            end
            if not self:mobility_check() then
                debug_lib.VisualDebugText({"ctron_status.stuck"}, worker, -2, 1)
                worker.autopilot_destination = nil
                self.last_distance = nil
            end
        end
        return false
    end
    return true
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
            item.quality = entity.quality.name
        else -- entity is an item_request_proxy
            _, item = next(entity.item_requests)
        end
        if item then
            if self.worker_logistic_network.can_satisfy_request({name = item.name, quality = item.quality}, item.count, true) then -- does inventory have the required item?
                can_build_entity = true
            end
        end
    end
    if not can_build_entity then
        table.remove(self.task_positions, 1)
    end
end

return construction_job
