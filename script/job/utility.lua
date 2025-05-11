local job = require("script/job")
local util_func = require("script/utility_functions")

-- sub class for utility jobs (set as _ENV as it is used in multiple files)
utility_job = setmetatable({}, job_metatable) ---@class utility_job : job
local utility_job_metatable = { __index = utility_job } ---@type metatable
script.register_metatable("utility_job_table", utility_job_metatable)

function utility_job.new(job_index, surface_index, job_type, worker)
    local self = job.new(job_index, surface_index, job_type, worker)
    setmetatable(self, utility_job_metatable)
    return self
end

--============================================================================--

function utility_job:robot_collection()
    local worker = self.worker ---@cast worker -nil
    local logistic_network = self.worker_logistic_network
    assert(logistic_network, "Missing logistic network!")
    if not next(logistic_network.construction_robots) then
        self.state = "finishing"
        return
    end
    if worker.autopilot_destination or self.path_request_id ~= nil then
        return
    end
    local distance = util_func.distance_between(worker.position, logistic_network.construction_robots[1].position)
    if distance > 3 then
        -- Get the positions of the Spidertron and the robot
        local spidertron_pos = worker.position
        local robot_pos = logistic_network.construction_robots[1].position
        -- Get the speed of the Spidertron and the robot
        local spidertron_speed = util_func.calculate_spidertron_speed(worker)
        local robot_speed = 0.05 -- hardcoded estimated speed of the Robot
        -- Calculate the vector from the Spidertron to the robot
        local dx = robot_pos.x - spidertron_pos.x
        local dy = robot_pos.y - spidertron_pos.y
        -- Calculate the distance between the Spidertron and the robot
        local distance1 = math.sqrt(dx * dx + dy * dy)
        -- Calculate the time it takes for them to meet
        local time_to_meet = distance / (spidertron_speed + robot_speed)
        -- Calculate the approximate meeting point
        local meeting_point = {
            x = spidertron_pos.x + spidertron_speed * time_to_meet * (dx / distance1),
            y = spidertron_pos.y + spidertron_speed * time_to_meet * (dy / distance1)
        }
        self:move_to_position(meeting_point)
    else
        -- check that robots are charging and if not, change job state to finishing
        local logistic_cell = worker.logistic_cell
        if logistic_cell and (logistic_cell.charging_robot_count == 0) then
            self.state = "finishing"
        end
    end
end

return utility_job