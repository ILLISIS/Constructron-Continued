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

function destroy_job:setup()
    -- calculate task positions
    self:calculate_task_positions()
    -- order tasks
    self:order_task_positions()
    -- request ammo
    self:request_ammo()
    -- enable_logistics_while_moving for destroy jobs
    local repair_tool = storage.repair_tool_name[self.surface_index]
    self.required_items[repair_tool.name] = { [repair_tool.quality] = storage.desired_robot_count[self.surface_index] * 4}
    -- vassals
    --     self.vassal_jobs = {}
    --     storage.vassal_count = 4 -- TODO: move to global and init
    --     self.state = "deferred"
    --     return
    -- state change
    self.state = "starting"
end

-- function destroy_job:position_check(position, distance)
--     local worker = self.worker ---@cast worker -nil
--     local distance_from_pos = util_func.distance_between(worker.position, position)
--     if distance_from_pos > distance then
--         debug_lib.VisualDebugText({"ctron_status.moving_to_pos"}, worker, -1, 1)
--         if not worker.autopilot_destination then
        --     if not self.path_request_id then
        --         self:move_to_position(position)
        --     end
        -- else
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
--                 debug_lib.VisualDebugText({"ctron_status.stuck"}, worker, -2, 1)
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
    --         debug_lib.VisualDebugText("Awaiting vassal proximity", worker, -1, 1) -- TODO localize!!
    --         worker.autopilot_destination = nil
    --         return
    --     end
    -- end

    local logistic_cell = self.worker_logistic_cell
    assert(logistic_cell, "Missing logistic cell!")
    local logistic_network = self.worker_logistic_network
    assert(logistic_network, "Missing logistic network!")

    -- check that the worker has contruction robots
    if (logistic_network.all_construction_robots < 1) then
        debug_lib.VisualDebugText({"ctron_status.missing_robots"}, worker, -0.5, 5)
        self.state = "starting"
        return
    end

    -- check health
    if not self:check_health() then return end
    -- check ammo
    if not self:check_ammo_count() then return end

    -- Am I in the correct position?
    local _, task_position = next(self.task_positions)
    if not self:position_check(task_position, 3) then return end

    --===========================================================================--
    --  Common logic
    --===========================================================================--
    local construction_robots = logistic_network.construction_robots

    debug_lib.VisualDebugText({"ctron_status.job_type_" .. self.job_type}, worker, -1, 1)
    self.job_status = {"ctron_status.job_type_" .. self.job_type}

    if not self.roboports_enabled then -- enable full roboport range (applies to landfil jobs)
        self:enable_roboports()
        return
    end

    if next(construction_robots) then -- are robots deployed?
        if not self:check_robot_activity(construction_robots) then -- are robots active?
            if (logistic_cell.charging_robot_count == 0) then
                self.last_robot_orientations = {}
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
    -- clear items
    if not self:clear_items() then return end
    -- clear logistic requests
    local logistic_point = self.worker.get_logistic_point(0) ---@cast logistic_point -nil
    local section = logistic_point.get_section(1)
    section.filters = {}
    -- randomize idle position around station
    self:randomize_idle_position()
    -- unlock constructron
    util_func.set_constructron_status(worker, 'busy', false)
    -- change selected constructron colour
    util_func.paint_constructron(worker, 'idle')
    -- release vassals -- TODO:
    -- for _, vassal_job in pairs((self.vassal_jobs or {})) do
    --     vassal_job.state = "finishing"
    -- end
    -- remove job from list
    storage.jobs[self.job_index] = nil
    debug_lib.VisualDebugText({"ctron_status.job_complete"}, worker, -1, 1)
end


local threat_weights = {
    -- nauvis enemies
    ["small-biter"] = 0.1,
    ["medium-biter"] = 0.5,
    ["big-biter"] = 1,
    ["behemoth-biter"] = 2,

    ["small-spitter"] = 0.5,
    ["medium-spitter"] = 1,
    ["big-spitter"] = 2,
    ["behemoth-spitter"] = 3,

    ["small-worm-turret"] = 1,
    ["medium-worm-turret"] = 2,
    ["big-worm-turret"] = 4,
    ["behemoth-worm-turret"] = 6,

    ["biter-spawner"] = 0.5,
    ["spitter-spawner"] = 0.5,

    -- Gleba enemies
    ["small-wriggler-pentapod"] = 1,
    ["medium-wriggler-pentapod"] = 1.5,
    ["big-wriggler-pentapod"] = 2,

    ["small-wriggler-pentapod-premature"] = 1,
    ["medium-wriggler-pentapod-premature"] = 1.5,
    ["big-wriggler-pentapod-premature"] = 2,

    ["small-strafer-pentapod"] = 4,
    ["medium-strafer-pentapod"] = 7,
    ["big-strafer-pentapod"] = 10,

    ["small-stomper-pentapod"] = 5,
    ["medium-stomper-pentapod"] = 10,
    ["big-stomper-pentapod"] = 15,

    ["gleba-spawner-small"] = 0.5,
    ["gleba-spawner"] = 0.5,

    -- Vulcanus enemies
    ["small-demolisher"] = 1000,
    ["medium-demolisher"] = 1000,
    ["big-demolisher"] = 1000
}

function destroy_job:determine_threat_level()
    -- Retrieve the worker associated with this job
    local worker = self.worker ---@cast worker -nil
    -- Get the health percentage of the worker (0 to 1)
    local healthperc = worker.get_health_ratio()
    -- Initialize the base threat modifier
    local threat_modifier = storage.global_threat_modifier
    -- Calculate the adjusted threat modifier based on health and minion jobs
    -- The threat modifier increases as health decreases and decreases with more minion jobs
    -- The minimum threat modifier is 0.1
    threat_modifier = threat_modifier + math.max((threat_modifier + ((1 - healthperc) * 2) - (table_size(self.minion_jobs) * 0.05)), 0.1)
    -- Find enemy entities within a radius of 64 around the worker's position
    local entities = worker.surface.find_entities_filtered {
        position = worker.position,
        radius = self.gun_range + 4,  -- Use the gun range of the worker
        force = {"enemy"},  -- Only consider entities that belong to the enemy force
        is_military_target = true  -- Only consider entities that are military targets
    }
    -- Initialize the threat factor based on nearby enemy entities
    local threat_factor = 0
    -- Loop through each enemy entity found
    for _, entity in pairs(entities) do
        -- If the entity has a defined threat weight, add it to the threat factor
        if threat_weights[entity.name] then
            threat_factor = threat_factor + threat_weights[entity.name]
        else
            -- If the entity is not known, increase the threat factor by a base amount
            threat_factor = threat_factor + 1
        end
    end
    -- Calculate the final threat level by multiplying the threat factor by the adjusted threat modifier
    local threat_level = (threat_factor * threat_modifier)
    -- Visual debug output to display the calculated threat level
    -- debug_lib.VisualDebugText("" .. threat_level .. "", worker, -0.5, 1)
    -- rendering.draw_text {
    --     text = threat_level,
    --     target = worker.position,
    --     filled = true,
    --     scale = 8,
    --     surface = worker.surface,
    --     time_to_live = 75,
    --     vertical_alignment = "middle",
    --     alignment = "center",
    --     color = {
    --         r = 255,
    --         g = 255,
    --         b = 255,
    --         a = 255
    --     }
    -- }
    -- Return the calculated threat level
    return threat_level
end

return destroy_job
