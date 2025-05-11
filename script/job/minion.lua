local job = require("script/job")
local util_func = require("script/utility_functions")
local debug_lib = require("script/debug_lib")

-- sub class for utility jobs (set as _ENV as it is used in multiple files)
local minion_job = setmetatable({}, job_metatable) ---@class minion_job : job
local minion_job_metatable = { __index = minion_job } ---@type metatable
script.register_metatable("minion_job_table", minion_job_metatable)

function minion_job.new(job_index, surface_index, job_type, worker)
    local self = job.new(job_index, surface_index, job_type, worker)
    setmetatable(self, minion_job_metatable)
    return self
end

--============================================================================--

function minion_job:setup()
    local worker = self.worker ---@cast worker -nil
    -- request ammo
    self:request_ammo()
    -- override robot request count
    local robot = storage.desired_robot_name[self.surface_index]
    self.required_items[robot.name] = { [robot.quality] = 4 }
    -- reqest repair tool
    local repair_tool = storage.repair_tool_name[self.surface_index]
    self.required_items[repair_tool.name] = { [repair_tool.quality] = 16}
    -- disable roboports
    self:disable_roboports(0)
    -- state change
    self.state = "starting"
end

function minion_job:starting()
    local worker = self.worker ---@cast worker -nil
    -- Am I in the correct position?
    if not self:position_check(self.station.position, 10) then return end
    -- Is the logistic network ready?
    local logistic_network = self.station.logistic_network
    if logistic_network.all_logistic_robots == 0 then
        debug_lib.VisualDebugText({"ctron_status.no_logi_robots"}, self.worker, -0.5, 3)
        return
    end
    -- request items / check inventory
    if not (self.sub_state == "items_requested") then
        local item_request_list = table.deepcopy(self.required_items)
        item_request_list = self:inventory_check(item_request_list)
        item_request_list = self:check_items_are_allowed(item_request_list)
        self:request_items(item_request_list)
        debug_lib.VisualDebugText({"ctron_status.requesting_items"}, worker, -1, 1)
        self.sub_state = "items_requested"
        self.request_tick = game.tick
        return
    else
        -- check if there are any items being delivered
        local requester_point = worker.get_logistic_point(0) ---@cast requester_point -nil
        if next(requester_point.targeted_items_deliver) then return end
        -- check if requested items have been delivered
        if not self:check_item_request_fulfillment() then
            debug_lib.VisualDebugText({"ctron_status.awaiting_logistics"}, worker, -1, 1)
            local ticks = (game.tick - self.request_tick)
            if not (ticks > 900) then return end
            if not (storage.stations_count[(self.surface_index)] > 1) then return end
            -- check items can be delivered
            if self:check_items_are_available() then return end
            -- check if items can be delivered at another station
            self:roam_stations()
            return
        end
        -- check trash has been taken
        if not self:check_trash() then
            -- IDEA: roam if unable to dump trash
            return
        end
    end
    -- divide ammo evenly between slots
    self:balance_ammunition()
    -- update job state
    self.sub_state = nil
    self.request_tick = nil
    self.state = "in_progress"
end

function minion_job:in_progress()
    self.job_status = "Following leader"
    local worker = self.worker ---@cast worker -nil
    -- check if the leader is alive and job is still valid
    if not storage.jobs[self.primary_job.job_index] or not self.primary_job.worker then
        self.state = "finishing" -- IDEA: assign util to primary?
        worker.autopilot_destination = nil
        return
    end
    -- check health
    if not self:check_health() then
        self.state = "repairing"
        return
    end
    -- check ammo
    if not self:check_ammo_count() then
        self.state = "starting"
        worker.autopilot_destination = nil
        self.primary_job.minion_jobs[self.job_index] = nil
        return
    end
    -- check proximity to leader
    local distance_from_pos = util_func.distance_between(worker.position, self.primary_job.worker.position)
    if distance_from_pos > 32 then
        worker.grid.inhibit_movement_bonus = false
        self:position_check(self.primary_job.worker.position, 5)
    else
        if worker.autopilot_destination then
            return
        else
            worker.follow_target = self.primary_job.worker
            debug_lib.VisualDebugText({"ctron_status.following_leader"}, worker, -1, 1)
        end
    end
end

-- this function handles the actions to take when the worker needs to repair
function minion_job:repairing()
    local worker = self.worker ---@cast worker -nil
    -- check if the leader is alive
    if not self.primary_job and self.primary_job.worker then
        self.state = "finishing" -- IDEA: assign util to primary?
        return
    end
    -- check the worker health and requirements to repair
    local health = worker.get_health_ratio()
    local logistic_cell = self.worker_logistic_cell
    assert(logistic_cell, "Missing logistic cell!")
    local logistic_network = self.worker_logistic_network
    assert(logistic_network, "Missing logistic network!")
    if health < 1 then
        -- set primary_job to repairing state
        self.primary_job.state = "repairing"
        -- check the worker has robots to repair
        if (logistic_network.all_construction_robots < 1) then
            debug_lib.VisualDebugText({"ctron_status.missing_robots"}, worker, -0.5, 5)
            self.primary_job.minion_jobs[self.job_index] = nil
            self.state = "starting"
            worker.autopilot_destination = nil
            return
        end
        -- check the worker has repair packs
        if not logistic_network.can_satisfy_request(storage.repair_tool_name[self.surface_index], 1, true) then
            self.primary_job.minion_jobs[self.job_index] = nil
            self.state = "starting"
            worker.autopilot_destination = nil
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

-- this function checks if the workers health is low
function minion_job:check_health()
    local worker = self.worker ---@cast worker -nil
    local health = worker.get_health_ratio()
    if health < 0.6 then
        debug_lib.VisualDebugText({"ctron_status.fleeing"}, worker, -0.5, 1)
        self.state = "repairing"
        return false
    end
    return true
end

return minion_job