local job = require("script/job")
local debug_lib = require("script/debug_lib")
local util_func = require("script/utility_functions")

-- sub class for logistic jobs
local cargo_job = setmetatable({}, job_metatable) ---@class cargo_job : job
local cargo_job_metatable = { __index = cargo_job } ---@type metatable
script.register_metatable("cargo_job_table", cargo_job_metatable)

function cargo_job.new(job_index, surface_index, job_type, worker)
    local self = job.new(job_index, surface_index, job_type, worker)
    setmetatable(self, cargo_job_metatable)
    return self
end

script.on_nth_tick(600, (function()
    cargo_job.prospect_cargo_jobs()
    for surface_index, _ in pairs(global.managed_surfaces) do
        cargo_job.process_cargo_job_queue(surface_index)
    end
end))


-- This function checks all stations for items that need to be restocked
function cargo_job.prospect_cargo_jobs()
    for _, station in pairs(global.service_stations) do
        local requests = global.station_requests[station.unit_number]
        if not next(requests) then goto continue end
        if not station.logistic_network then goto continue end
        local items_to_fullfill = {}
        for id, request in pairs(requests) do
            local current_count = station.logistic_network.get_item_count(request.item)
            if not ((current_count + request.in_transit_count) > request.min) then
                items_to_fullfill[request.item] = request.max
                global.station_requests[station.unit_number][id].in_transit_count = request.max
            end
        end
        if not next(items_to_fullfill) then goto continue end
        -- top up all items at the station
        for id, request in pairs(requests) do
            local current_count = station.logistic_network.get_item_count(request.item)
            if ((current_count + request.in_transit_count) < request.max) then
                if not items_to_fullfill[request.item] then -- ignore if already in the list
                    local total = request.max - current_count - request.in_transit_count
                    items_to_fullfill[request.item] = total
                    global.station_requests[station.unit_number][id].in_transit_count = total
                end
            end
        end
        global.cargo_index = global.cargo_index + 1
        global.cargo_queue[station.surface_index][global.cargo_index] = {
            index = global.cargo_index,
            station = station,
            items = items_to_fullfill
        }
        ::continue::
    end
end

-- This function processes the cargo job queue
function cargo_job.process_cargo_job_queue(surface_index)
    if not next(global.cargo_queue[surface_index]) then return end
    for index, queued_job in pairs(global.cargo_queue[surface_index]) do
        local station = queued_job.station
        if not (station and station.valid) then
            global.cargo_queue[surface_index][index] = nil
        else
            if not cargo_job.make_cargo_job(station, queued_job.items) then return end
            global.cargo_queue[surface_index][index] = nil
        end
    end
end

-- This function creates a new cargo job
function cargo_job.make_cargo_job(station, items_to_fullfill)
    local station_surface_index = station.surface.index
    local worker = job.get_worker(station_surface_index)
    if not (worker and worker.valid) then
        return false
    end
    global.job_index = global.job_index + 1
    global.jobs[global.job_index] = cargo_job.new(global.job_index, station_surface_index, "cargo", worker)
    global.jobs[global.job_index].state = "setup"
    global.jobs[global.job_index].destination_station = station
    table.insert(global.jobs[global.job_index].task_positions, station.position)
    global.jobs[global.job_index].required_items = items_to_fullfill
    global.job_proc_trigger = true -- start job operations
    return true
end

-- this function checks if another station can provide the items being requested
function cargo_job:roam_stations(current_requests)
    local surface_stations = util_func.get_service_stations(self.surface_index)
    for _, station in pairs(surface_stations) do
        -- check that the candidate station is not the destination station
        if self.destination_station and self.destination_station.valid and not (station.unit_number == self.destination_station.unit_number) then
            if self:check_roaming_candidate(station, current_requests) then
                return
            end
        end
    end
end

--===========================================================================--
--  State Logic
--===========================================================================--


function cargo_job:setup()
    -- check if cargo can fit in the inventory
    self.empty_slot_count = self.worker_inventory.count_empty_stacks()
    local total_required_slots = util_func.calculate_required_inventory_slot_count(self.required_items)
    if total_required_slots > self.empty_slot_count then
        -- job will not fit in one constructron, split the job to use multiple constructrons
        local divisor = math.ceil(total_required_slots / (self.empty_slot_count - 1))
        for item, count in pairs(self.required_items) do
            self.required_items[item] = math.ceil(count / divisor)
        end
        if divisor > 1 then
            for i = 1, divisor - 1 do
                global.cargo_index = global.cargo_index + 1
                global.cargo_queue[self.surface_index][global.cargo_index] = {
                    index = global.cargo_index,
                    station = self.destination_station,
                    items = self.required_items
                }
            end
            cargo_job.process_cargo_job_queue(self.surface_index)
        end
    end
    -- set default ammo request
    if global.ammo_count[self.surface_index] > 0 and (self.worker.name ~= "constructron-rocket-powered") then
        self.required_items[global.ammo_name[self.surface_index]] = global.ammo_count[self.surface_index]
    end
    -- check if the home station is the destination station
    if (self.station.unit_number == self.destination_station.unit_number) then
        self:roam_stations({})
    end
    -- state change
    self.state = "starting"
end

function cargo_job:in_progress()
    local worker = self.worker ---@cast worker -nil
    -- check health
    if not self:check_health() then return end
    -- Am I in the correct position?
    local _, task_position = next(self.task_positions)
    if not self:position_check(task_position, 3) then return end
    if not (self.sub_state == "unloading_items") then
        self:deliver_items()
        self.sub_state = "unloading_items"
        return
    else
        if not self:check_trash() then
            local trash_items = self.worker_trash_inventory.get_contents()
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
            return
        end
        for i = 1, worker.request_slot_count do ---@cast i uint
            local request = worker.get_vehicle_logistic_slot(i)
            if request then
                worker.clear_vehicle_logistic_slot(i)
            end
        end
        self.sub_state = nil
        self.state = "finishing"
    end
end

function cargo_job:deliver_items()
    local station_unit_number = self.destination_station.unit_number
    local slot = 1
    for _, request in pairs(global.station_requests[station_unit_number]) do
        local requested_item = request.item
        for item, item_count in pairs(self.required_items) do
            if requested_item == item then
                request.in_transit_count = request.in_transit_count - item_count
                self.worker.set_vehicle_logistic_slot(slot, {
                    name = item,
                    min = 0,
                    max = 0
                })
                slot = slot + 1
            end
        end
    end
end

return cargo_job