local job = require("script/job")
local util_func = require("script/utility_functions")
local debug_lib = require("script/debug_lib")

-- sub class for utility jobs
local utility_job = setmetatable({}, job_metatable) ---@class utility_job : job
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
    local logistic_network = worker.logistic_cell.logistic_network ---@cast logistic_network -nil
    if next(logistic_network) and logistic_network.construction_robots[1] then
        local distance = util_func.distance_between(worker.position, logistic_network.construction_robots[1].position)
        if not worker.autopilot_destination and self.path_request_id == nil then
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
    else
        self.state = "finishing"
    end
end

-- function utility_job:vassal_new()
--     -- set default ammo request
--     if global.ammo_count[self.surface_index] > 0 and (worker.name ~= "constructron-rocket-powered") then
--         self.required_items[global.ammo_name[self.surface_index]] = global.ammo_count[self.surface_index]
--     end
--     self.required_items[global.repair_tool_name[self.surface_index]] = global.desired_robot_count[self.surface_index] * 4
--     -- state change
--     self.state = "starting"
-- end

-- function utility_job:vassal_starting()
--     -- Am I in the correct position?
--     if not self:position_check(self.station.position, 10) then return end
--     -- set combinator station
--     global.constructron_requests[worker.unit_number].station = self.station
--     -- Is the logistic network ready?
--     local logistic_network = self.station.logistic_network
--     if logistic_network.all_logistic_robots == 0 then
--         debug_lib.VisualDebugText("No logistic robots in network", self.worker, -0.5, 3)
--         return
--     end
--     -- request items / check inventory
--     local inventory = worker.get_inventory(defines.inventory.spider_trunk) ---@cast inventory -nil -- spider inventory
--     local inventory_items = inventory.get_contents() -- spider inventory contents
--     local ammo_slots = worker.get_inventory(defines.inventory.spider_ammo) ---@cast ammo_slots -nil -- ammo inventory
--     local ammunition = ammo_slots.get_contents() -- ammo inventory contents
--     local current_items = job_proc.combine_tables({inventory_items, ammunition})
--     if not (self.sub_state == "items_requested") then
--         local item_request_list = table.deepcopy(self.required_items)
--         -- check inventory for unwanted items
--         for item, _ in pairs(current_items) do
--             if not self.required_items[item] then
--                 item_request_list[item] = 0
--             end
--         end
--         -- check ammo slots for unwanted items
--         for item, _ in pairs(ammunition) do
--             if item ~= global.ammo_name[self.surface_index] then
--                 item_request_list[item] = 0
--             end
--         end
--         item_request_list = self:check_items_are_allowed(item_request_list)
--         self:request_items(item_request_list)
--         self.sub_state = "items_requested"
--         self.request_tick = game.tick
--         return
--     else
--         --populate current requests
--         local current_requests = self:list_item_requests()
--         -- check if requested items have been delivered
--         if not self:check_item_requests(current_requests, current_items) then
--             -- station roaming
--             local ticks = (game.tick - self.request_tick)
--             if not (ticks > 900) then return end
--             if self:check_requests(current_requests) then return end
--             self:roam_stations(current_requests)
--             return
--         end
--         -- check trash has been taken
--         if not self:check_trash() then
--             -- IDEA: roam if unable to dump trash
--             return
--         end
--     end
--     -- divide ammo evenly between slots
--     self:balance_ammunition(ammo_slots, ammunition)
--     -- update job state
--     self.sub_state = nil
--     self.request_tick = nil
--     self.state = "in_progress"
-- end

-- function utility_job:vassal_in_progress()
--     -- check health
--     if not self:check_health() then
--         -- self.primary_job.vassal_job[self.] = nil -- TODO: finish. remove vassal job from primary job
--         return
--     end
--     -- TODO: move ammo check here
--     if not self.primary_job.worker then
--         self.state = "finishing" -- IDEA: TODO: assign util to primary?
--         return
--     end
--     local distance_from_pos = util_func.distance_between(worker.position, self.primary_job.worker.position)
--     if distance_from_pos > 32 then
--         self:position_check(self.primary_job.worker.position, 5)
--     else
--         if worker.autopilot_destination then
--             return
--         else
--             worker.follow_target = self.primary_job.worker
--         end
--     end
-- end

return utility_job