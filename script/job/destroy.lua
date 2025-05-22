local job = require("script/job")
local debug_lib = require("script/debug_lib")
local util_func = require("script/utility_functions")
local minion_job = require("script/job/minion")
local color_lib = require("script/color_lib")

-- sub class for destroy jobs
local destroy_job = setmetatable({}, job_metatable) ---@class destroy_job : job
local destroy_job_metatable = { __index = destroy_job } ---@type metatable
script.register_metatable("destroy_job_table", destroy_job_metatable)

function destroy_job.new(job_index, surface_index, job_type, worker)
    local self = job.new(job_index, surface_index, job_type, worker)
    setmetatable(self, destroy_job_metatable)
    self.minion_jobs = {}
    self.safe_positions = {}
    self.considered_spawners = {}
    self.gun_range = 36 -- default range of normal quality spidertron
    return self
end

local gun_range = {
    ["normal"] = 36,
    ["uncommon"] = 39.6,
    ["rare"] = 43.2,
    ["epic"] = 46.8,
    ["legendary"] = 54
}

function destroy_job:setup()
    -- summon minions to help
    for i = 1, (storage.minion_count[self.surface_index] - table_size(self.minion_jobs)) do
        -- find a worker to perform the prospective minion job
        local new_worker = job.get_worker(self.surface_index)
        if not (new_worker and new_worker.valid) then
            debug_lib.VisualDebugText({"ctron_status.missing_minions"}, self.worker, -0.5, 5)
            return
        end
        -- create the job
        storage.job_index = storage.job_index + 1
        storage.jobs[storage.job_index] = minion_job.new(storage.job_index, self.surface_index, "minion", new_worker)
        -- set the primary_job on the minion_job
        storage.jobs[storage.job_index].primary_job = self
        -- add the minion_job to the minion jobs list on the primary_job
        self.minion_jobs[storage.job_index] = storage.jobs[storage.job_index]
    end
    -- calculate task positions
    self:calculate_task_positions()
    -- order tasks
    self:order_task_positions()
    -- request ammo
    self:request_ammo()
    -- override robot request count
    local robot = storage.desired_robot_name[self.surface_index]
    self.required_items[robot.name] = { [robot.quality] = 4 }
    -- reqest repair tool
    local repair_tool = storage.repair_tool_name[self.surface_index]
    self.required_items[repair_tool.name] = { [repair_tool.quality] = 16}
    -- set the gun range based on the workers quality
    self.gun_range = gun_range[self.worker.quality.name]
    -- disable roboports
    self:disable_roboports(0)
    -- state change
    self.state = "starting"
end

function destroy_job:in_progress()
    local worker = self.worker ---@cast worker -nil
    if not next(self.task_positions) then
        self:check_chunks()
        self.state = "finishing"
        return
    end

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
    -- display range (for debugging)
    -- show_radius(worker)
    -- atomic attack
    if storage.atomic_ammo_count[self.surface_index] > 0 then
        -- check if the worker has atomic ammo in its inventory
        local bomb_count = self.worker_inventory.get_item_count(storage.atomic_ammo_name[self.surface_index])
        if bomb_count > 0 then
            -- find all enemy spawners in missle range
            local entities = worker.surface.find_entities_filtered {
                position = worker.position,
                radius = self.gun_range,
                force = {"enemy"},
                type = { "unit-spawner" }
            }
            for _, entity in pairs(entities) do
                if not self.considered_spawners[entity.unit_number] then
                    -- find clustered spawners
                    local surounding_entities = entity.surface.find_entities_filtered {
                        position = entity.position,
                        radius = 17.5, -- default area of effect radius of atomic-bomb
                        force = {"enemy"},
                        type = { "unit-spawner" }
                    }
                    -- if cluster is found in range
                    if #surounding_entities > storage.destroy_min_cluster_size[self.surface_index] then
                        -- check distance between worker and target is more than minimum safe distance
                        local distance_from_pos = util_func.distance_between(worker.position, entity.position)
                        if distance_from_pos > 36 then
                            -- deduct ammo from the workers inventory
                            local bomb = storage.atomic_ammo_name[self.surface_index]
                            self.worker_inventory.remove({name = bomb.name, quality = bomb.quality, count = 1})
                            self:launch_nuke(entity, surounding_entities)
                            break
                        end
                    else
                        -- mark as considered target to avoid rechecks
                        self.considered_spawners[entity.unit_number] = true
                    end
                end
            end
        end
    end
    -- determine the threat level of the area
    local threat_level = self:determine_threat_level()
    if (threat_level < 50) then
        self.wpflag = nil -- used to determine if the worker is actively evading attacks
        -- set safe_positions
        if threat_level < 40 then
            local last_safe_pos = self.safe_positions[#self.safe_positions] or self.station.position
            local distance_from_pos = util_func.distance_between(worker.position, last_safe_pos)
            if distance_from_pos > 16 then
                -- add the position to the safe_positions list
                table.insert(self.safe_positions, {y = math.floor(worker.position.y), x = math.floor(worker.position.x)})
                -- debug_lib.VisualDebugCircle(worker.position, self.surface_index, "yellow", 2, 60)
            end
        end
        self.retreating = nil
        -- minion checks
        for id, minionjob in pairs(self.minion_jobs) do
            if not self:check_minion_status(minionjob) then return end
        end
        -- Am I in the correct position?
        local _, task_position = next(self.task_positions) ---@cast task_position MapPosition.0
        if not self:position_check(task_position, 3) then return end
    elseif (threat_level < 100) then
        debug_lib.VisualDebugText({"ctron_status.standing_gound"}, worker, 1, 1)
        if not self.wpflag then
            worker.autopilot_destination = nil
            self.wpflag = true
        end
        if worker.autopilot_destination == nil then
            self:perform_evasion()
        end
        return
    else
        local safe_pos = self.safe_positions[#self.safe_positions] or self.station.position
        if self.retreating then
            -- check if the worker is already in range of the safe position
            local distance_from_pos = util_func.distance_between(worker.position, safe_pos)
            if worker.autopilot_destination == nil then
                if  distance_from_pos > 6 then
                    worker.autopilot_destination = safe_pos
                elseif distance_from_pos < 7 then
                    debug_lib.VisualDebugText({"ctron_status.safe_position"}, worker, 1, 1)
                    -- remove the last safe position from the list
                    self.safe_positions[#self.safe_positions] = nil
                    if #self.safe_positions == 0 then
                        -- if there are no more safe positions, go to the station
                        self.safe_positions[#self.safe_positions] = self.station.position
                    end
                    -- go to a further away safe position
                    worker.autopilot_destination = self.safe_positions[#self.safe_positions]
                    -- debug_lib.VisualDebugCircle(self.safe_positions[#self.safe_positions], self.surface_index, "black", 2, 60)
                end
            else
                if distance_from_pos < 7 then
                    debug_lib.VisualDebugText({"ctron_status.safe_position"}, worker, 1, 1)
                    -- remove the last safe position from the list
                    self.safe_positions[#self.safe_positions] = nil
                    if #self.safe_positions == 0 then
                        -- if there are no more safe positions, go to the station
                        self.safe_positions[#self.safe_positions] = self.station.position
                    end
                    -- go to a further away safe position
                    worker.autopilot_destination = self.safe_positions[#self.safe_positions]
                    -- debug_lib.VisualDebugCircle(self.safe_positions[#self.safe_positions], self.surface_index, "black", 2, 60)
                end
            end
            return
        else
            debug_lib.VisualDebugText({"ctron_status.safe_position"}, worker, 1, 1)
            -- debug_lib.VisualDebugCircle(self.safe_positions[#self.safe_positions], self.surface_index, "black", 2, 60)
            -- go to the last position deemed safe
            worker.autopilot_destination = safe_pos
            self.retreating = true
            return
        end
    end
    --===========================================================================--
    --  Common logic
    --===========================================================================--
    debug_lib.VisualDebugText({"ctron_status.job_type_" .. self.job_type}, worker, -1, 1)
    self.job_status = {"ctron_status.job_type_" .. self.job_type}
    self:specific_action(threat_level)
end

function destroy_job:specific_action(threat_level)
    local worker = self.worker
    if #self.task_positions == 1 then
        if threat_level < 3 then -- threat is determined larger than weapon range
            table.remove(self.task_positions, 1)
        else
            -- find enemy
            local entities = worker.surface.find_entities_filtered {
                position = worker.position,
                radius = self.gun_range,
                force = {"enemy"},
                is_military_target = true
            }
            if not next(entities) then
                table.remove(self.task_positions, 1)
            end
        end
    elseif threat_level < 50 then
        table.remove(self.task_positions, 1)
    else
        if not self.wpflag then
            worker.autopilot_destination = nil
            self.wpflag = true
        end
        if worker.autopilot_destination == nil then
            self:perform_evasion()
        end
    end
end

function destroy_job:finishing()
    local worker = self.worker ---@cast worker -nil
    worker.enable_logistics_while_moving = false
    if not self:position_check(self.station.position, 10) then return end
    -- enable roboports
    self:enable_roboports()
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
    -- release minions
    for _, minionjob in pairs(self.minion_jobs) do
        minionjob.state = "finishing"
    end
    -- remove job from list
    storage.jobs[self.job_index] = nil
    debug_lib.VisualDebugText({"ctron_status.job_complete"}, worker, -1, 1)
end

function destroy_job:perform_evasion()
    local worker = self.worker ---@cast worker -nil
    local spots = generate_waypoints(worker.position, 4, 7)
    for _, spot in ipairs(spots) do
        worker.add_autopilot_destination(spot)
    end
end

function generate_waypoints(original_position, num_waypoints, radius)
    local waypoints = {}
    local angle_increment = (2 * math.pi) / num_waypoints
    for i = 0, num_waypoints - 1 do
        local angle = i * angle_increment
        local waypoint = {
            x = original_position.x + radius * math.cos(angle),
            y = original_position.y + radius * math.sin(angle)
        }
        table.insert(waypoints, waypoint)
    end
    -- Return to the original position as the last waypoint
    table.insert(waypoints, original_position)
    return waypoints
end

function destroy_job:repairing()
    local threat_level = self:determine_threat_level()
    local worker = self.worker ---@cast worker -nil
    if (threat_level > 50) then
        self.safe_positions[#self.safe_positions] = nil
        worker.autopilot_destination = self.safe_positions[#self.safe_positions]
        -- debug_lib.VisualDebugCircle(self.safe_positions[#self.safe_positions], self.surface_index, "black", 2, 60)
    else
        local health = worker.get_health_ratio()
        local logistic_cell = self.worker_logistic_cell
        assert(logistic_cell, "Missing logistic cell!")
        local logistic_network = self.worker_logistic_network
        assert(logistic_network, "Missing logistic network!")
        if health < 1 then
            -- check the worker has robots to repair
            if (logistic_network.all_construction_robots < 1) then
                debug_lib.VisualDebugText({"ctron_status.missing_robots"}, worker, -0.5, 5)
                self.state = "starting"
                return
            end
            -- check the worker has repair packs
            if not logistic_network.can_satisfy_request(storage.repair_tool_name[self.surface_index], 1, true) then
                self.state = "starting"
                return
            end
            -- enable roboports
            self:enable_roboports()
            debug_lib.VisualDebugText({"ctron_status.job_type_repair"}, worker, -0.5, 1)
        else
            -- disable roboports
            self:disable_roboports(0)
            local construction_robots = logistic_network.construction_robots
            if next(construction_robots) then
                -- do not proceed with job until robots are docked
                return
            end
            self.state = "in_progress"
        end
    end
end

-- this function checks if the workers health is low
function destroy_job:check_health()
    local worker = self.worker ---@cast worker -nil
    local health = worker.get_health_ratio()
    if health < 0.6 then
        debug_lib.VisualDebugText({"ctron_status.fleeing"}, worker, -0.5, 1)
        self.state = "repairing"
        return false
    end
    return true
end

function destroy_job:request_ammo()
    if storage.ammo_count[self.surface_index] > 0 and (self.worker.name ~= "constructron-rocket-powered") then
        local ammo = storage.ammo_name[self.surface_index]
        self.required_items[ammo.name] = { [ammo.quality] = storage.ammo_count[self.surface_index] }
    end
    if storage.atomic_ammo_count[self.surface_index] > 0 then
        local atomic_ammo = storage.atomic_ammo_name[self.surface_index]
        self.required_items[atomic_ammo.name] = { [atomic_ammo.quality] = storage.atomic_ammo_count[self.surface_index] }
    end
end

-- this function checks the status of minion jobs and takes action if needed
---@param minionjob table
---@return boolean
function destroy_job:check_minion_status(minionjob)
    local minion = minionjob.worker
    if not minion or not minion.valid then return true end
    -- check minions proximity to worker
    local worker = self.worker ---@cast worker -nil
    local distance = util_func.distance_between(worker.position, minion.position)
    if distance > 32 or minion.follow_target == nil then
        debug_lib.VisualDebugText({"ctron_status.minion_proximity"}, worker, -1, 1)
        worker.autopilot_destination = nil
        return false
    end
    return true
end

function destroy_job:launch_nuke(target, surounding_entities)
    local worker = self.worker ---@cast worker -nil
    local bomb = storage.atomic_ammo_name[self.surface_index]
    -- spawn atomic rocket
    worker.surface.create_entity {
        name = bomb.name,
        quality = bomb.quality,
        position = worker.position,
        target = target.position,
        speed = 0.4,
        force = worker.force
    }
    -- stop moving to avoid entering the explosion radius
    worker.autopilot_destination = nil
    -- mark surounding_entities as considered targets to avoid double ups
    self.considered_spawners[target.unit_number] = true
    for _, neighbour_entity in pairs(surounding_entities) do
        self.considered_spawners[neighbour_entity.unit_number] = true
    end
end

-- used during debugging to draw a the radius
-- function show_radius(ctron)
--     if not (ctron and ctron.valid) then return end
--     local radius = 55
--     local min = {x = (ctron.position.x - radius), y = (ctron.position.y - radius)}
--     local max = {x = (ctron.position.x + radius), y = (ctron.position.y + radius)}
--     debug_lib.draw_rectangle(min, max, ctron.surface, "blue", false, 30)
-- end

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
