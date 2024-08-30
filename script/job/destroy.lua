local job = require("script/job")
local debug_lib = require("script/debug_lib")
local util_func = require("script/utility_functions")

-- sub class for destroy jobs
local destroy_job = setmetatable({}, job_metatable) ---@class destroy_job : job
local destroy_job_metatable = { __index = destroy_job } ---@type metatable
script.register_metatable("destroy_job_table", destroy_job_metatable)

function destroy_job.new(job_index, surface_index, job_type, worker)
    local self = job.new(job_index, surface_index, job_type, worker)
    setmetatable(self, destroy_job_metatable)
    return self
end


-- function destroy_job:setup()
--     local worker = self.worker ---@cast worker -nil
--     -- calculate chunk build positions
--     for _, chunk in pairs(self.chunks) do
--         debug_lib.draw_rectangle(chunk.minimum, chunk.maximum, self.surface_index, "yellow", false, 3600)
--         local positions = util_func.calculate_construct_positions({chunk.minimum, chunk.maximum}, worker.logistic_cell.construction_radius * 0.95) -- 5% tolerance
--         for _, position in ipairs(positions) do
--             debug_lib.VisualDebugCircle(position, self.surface_index, "yellow", 0.5, 3600)
--             table.insert(self.task_positions, position)
--         end
--         if chunk.required_items["landfill"] then
--             self.landfill_job = true
--         end
--     end
--     -- set default ammo request
--     if global.ammo_count[self.surface_index] > 0 and (worker.name ~= "constructron-rocket-powered") then
--         self.required_items[global.ammo_name[self.surface_index]] = global.ammo_count[self.surface_index]
--     end
--     -- enable_logistics_while_moving for destroy jobs
--     if self.job_type == "destroy" then
--         self.required_items[global.repair_tool_name[self.surface_index]] = global.desired_robot_count[self.surface_index] * 4
--         -- vassals
--         self.vassal_jobs = {}
--         global.vassal_count = 4 -- TODO: move to global and init
--         self.state = "deferred"
--         return
--     end
--     -- state change
--     self.state = "starting"
-- end

-- function destroy_job:position_check(position, distance)
--     local worker = self.worker ---@cast worker -nil
--     local distance_from_pos = util_func.distance_between(worker.position, position)
--     if distance_from_pos > distance then
--         debug_lib.VisualDebugText("Moving to position", worker, -1, 1)
--         if not worker.autopilot_destination and self.path_request_id == nil then
--             self:move_to_position(position)
--         else
--             entities = worker.surface.find_entities_filtered {
--                 position = worker.position,
--                 radius = 32,
--                 force = {"enemy"},
--                 is_military_target = true
--             } -- only detects entities in range
--             if (#entities > 15) then
--                 worker.autopilot_destination = nil

--                 local positions = generate_random_waypoints(worker.position, 4, 8)

--                 for _, waypoint in ipairs(positions) do
--                     worker.add_autopilot_destination(waypoint)
--                 end
--             end
--             if not self:mobility_check() then
--                 debug_lib.VisualDebugText("Stuck!", worker, -2, 1)
--                 worker.autopilot_destination = nil
--                 self.last_distance = nil
--             end
--         end
--         return false
--     end
--     return true
-- end

-- function generate_random_waypoints(position, num_waypoints, distance)
--     local waypoints = {}
--     for i = 1, num_waypoints do
--         -- Generate a random angle in radians
--         local angle = math.random() * 2 * math.pi
--         -- Calculate the offset based on the angle and distance
--         local offset_x = math.cos(angle) * distance
--         local offset_y = math.sin(angle) * distance
--         -- Calculate the waypoint position
--         local waypoint = {
--             x = position.x + offset_x,
--             y = position.y + offset_y
--         }
--         -- Add the waypoint to the list
--         table.insert(waypoints, waypoint)
--     end
--     return waypoints
-- end


function destroy_job:in_progress()
    local worker = self.worker ---@cast worker -nil
    if not next(self.task_positions) then
        self:check_chunks()
        self.state = "finishing"
        return
    end

    -- for k, vassal_job in pairs(self.vassal_jobs) do
    --     if vassal_job.state == "finishing" then
    --         table.remove(self.vassal_jobs, k)
    --         break
    --     end
    --     vassal_worker = vassal_job.worker
    --     if not vassal_worker.valid then -- TODO: potential issue with vassal job being validated and reassigned before this is parsed
    --         break
    --     end
    --     -- distance check
    --     local distance = util_func.distance_between(worker.position, vassal_worker.position)
    --     if distance > 32 then
    --         debug_lib.VisualDebugText("Awaiting vassal proximity", worker, -1, 1)
    --         worker.autopilot_destination = nil
    --         return
    --     end
    -- end

    local logistic_cell = worker.logistic_cell
    local logistic_network = logistic_cell.logistic_network ---@cast logistic_network -nil

    -- check that the worker has contruction robots
    if (logistic_network.all_construction_robots < 1) then
        debug_lib.VisualDebugText("Missing robots! returning to station.", worker, -0.5, 5)
        self.state = "starting"
        return
    end

    -- check health
    if not self:check_health() then return end
    -- TODO: move ammo check here

    -- Am I in the correct position?
    local _, task_position = next(self.task_positions)
    if not self:position_check(task_position, 3) then return end

    --===========================================================================--
    --  Common logic
    --===========================================================================--
    local construction_robots = logistic_network.construction_robots

    debug_lib.VisualDebugText("".. self.job_type .."", worker, -1, 1)

    if not self.roboports_enabled then -- enable full roboport range (applies to landfil jobs)
        self:enable_roboports()
        return
    end

    if next(construction_robots) then -- are robots deployed?
        if not self:check_robot_activity(construction_robots) then -- are robots active?
            if (logistic_cell.charging_robot_count == 0) then
                self.last_robot_positions = {}
                table.remove(self.task_positions, 1)
            end
        end
    else -- robots are not deployed
        self:specific_action()
    end
end


function destroy_job:finishing()
    local worker = self.worker ---@cast worker -nil
    worker.enable_logistics_while_moving = false
    if not self:position_check(self.station.position, 10) then return end
    if not self.roboports_enabled then -- enable full roboport range (due to landfil jobs disabling them)
        self:enable_roboports()
    end
    -- clear items
    local inventory_items = self.worker_inventory.get_contents()
    if not (self.sub_state == "items_requested") then
        local item_request = {}
        for item, _ in pairs(inventory_items) do
            item_request[item] = 0
        end
        self:request_items(item_request)
        self.sub_state = "items_requested"
        self.request_tick = game.tick
        return
    else
        -- check trash has been taken
        local trash_items = self.worker_trash_inventory.get_contents()
        if next(trash_items) then
            local logistic_network = self.station.logistic_network
            if (logistic_network.all_logistic_robots <= 0) then
                debug_lib.VisualDebugText("No logistic robots in network", worker, -0.5, 3)
            end
            if not next(logistic_network.storages) then
                debug_lib.VisualDebugText("No storage in network", worker, -0.5, 3)
            else
                for item_name, item_count in pairs(trash_items) do
                    local can_drop = logistic_network.select_drop_point({stack = {name = item_name, count = item_count}})
                    if can_drop then
                        debug_lib.VisualDebugText("Awaiting logistics", worker, -1, 1)
                        return
                    end
                end
            end
            -- check if other station networks can store items
            local surface_stations = util_func.get_service_stations(self.surface_index)
            for _, station in pairs(surface_stations) do
                if station.logistic_network then
                    for item_name, item_count in pairs(trash_items) do
                        local can_drop = station.logistic_network.select_drop_point({stack = {name = item_name, count = item_count}})
                        if can_drop then
                            debug_lib.VisualDebugText("Trying a different station", worker, 0, 5)
                            self.station = station
                            return
                        end
                    end
                end
            end
            return
        else
            self.sub_state = nil
            self.request_tick = nil
            for i = 1, worker.request_slot_count do ---@cast i uint
                local request = worker.get_vehicle_logistic_slot(i)
                if request then
                    worker.clear_vehicle_logistic_slot(i)
                end
            end
        end
        -- clear combinator request cache
        global.constructron_requests[worker.unit_number].requests = {}
    end
    -- randomize idle position around station
    if (global.constructrons_count[self.surface_index] > 10) then
        local stepdistance = 5 + math.random(5)
        local alpha = math.random(360)
        local offset = {x = (math.cos(alpha) * stepdistance), y = (math.sin(alpha) * stepdistance)}
        local new_position = {x = (worker.position.x + offset.x), y = (worker.position.y + offset.y)}
        worker.autopilot_destination = new_position
    end
    -- unlock constructron
    util_func.set_constructron_status(worker, 'busy', false)
    global.available_ctron_count[self.surface_index] = global.available_ctron_count[self.surface_index] + 1
    -- update combinator with dummy entity to reconcile available_ctron_count
    -- job_proc.update_combinator(self.station, "constructron_pathing_proxy_1", 0) -- TODO: fix this
    -- change selected constructron colour
    util_func.paint_constructron(worker, 'idle')
    -- release vassals -- TODO:
    -- for _, vassal_job in pairs((self.vassal_jobs or {})) do
    --     vassal_job.state = "finishing"
    -- end
    -- remove job from list
    global.jobs[self.job_index] = nil
    debug_lib.VisualDebugText("Job complete!", worker, -1, 1)
end

function destroy_job:specific_action()
    local worker = self.worker
    -- check ammo
    local ammunition = self.worker_ammo_slots.get_contents()
    -- retreat when at 25% of ammo
    local ammo_name = global.ammo_name[self.surface_index]
    if ammunition and ammunition[ammo_name] and ammunition[ammo_name] < (math.ceil(global.ammo_count[self.surface_index] * 25 / 100)) then
        self.state = "finishing" -- TODO: should this be "starting"?
        return
    end
    local entities = worker.surface.find_entities_filtered {
        position = worker.position,
        radius = 32,
        force = {"enemy"},
        is_military_target = true
    } -- only detects entities in range
    if not next(entities) then
        table.remove(self.task_positions, 1)
    end
end

return destroy_job