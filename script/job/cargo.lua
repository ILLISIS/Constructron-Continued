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
    for surface_index, _ in pairs(storage.managed_surfaces) do
        cargo_job.process_cargo_job_queue(surface_index)
    end
end))


-- This function checks all stations for items that need to be restocked
function cargo_job.prospect_cargo_jobs()
    for _, station in pairs(storage.service_stations) do
        local requests = storage.station_requests[station.unit_number]
        if not next(requests) then goto continue end
        if not station.logistic_network then goto continue end
        local items_to_fullfill = {}
        for id, request in pairs(requests) do
            local current_count = station.logistic_network.get_item_count(request.name)
            if not ((current_count + request.in_transit_count) > request.min) then
                items_to_fullfill[request.name] = { [request.quality] = request.max }
                storage.station_requests[station.unit_number][id].in_transit_count = request.max
            end
        end
        if not next(items_to_fullfill) then goto continue end
        -- top up all items at the station
        for id, request in pairs(requests) do
            local current_count = station.logistic_network.get_item_count(request.name)
            if ((current_count + request.in_transit_count) < request.max) then
                if not (items_to_fullfill[request.name] and items_to_fullfill[request.name][request.quality]) then -- ignore if already in the list
                    local total = request.max - current_count - request.in_transit_count
                    items_to_fullfill[request.name] = items_to_fullfill[request.name] or {}
                    items_to_fullfill[request.name][request.quality] = total
                    storage.station_requests[station.unit_number][id].in_transit_count = total
                end
            end
        end
        storage.cargo_index = storage.cargo_index + 1
        storage.cargo_queue[station.surface_index][storage.cargo_index] = {
            index = storage.cargo_index,
            station = station,
            items = items_to_fullfill
        }
        ::continue::
    end
end

-- This function processes the cargo job queue
function cargo_job.process_cargo_job_queue(surface_index)
    if not next(storage.cargo_queue[surface_index]) then return end
    for index, queued_job in pairs(storage.cargo_queue[surface_index]) do
        local station = queued_job.station
        if not (station and station.valid) then
            storage.cargo_queue[surface_index][index] = nil
        else
            if not cargo_job.make_cargo_job(station, queued_job.items) then return end
            storage.cargo_queue[surface_index][index] = nil
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
    storage.job_index = storage.job_index + 1
    storage.jobs[storage.job_index] = cargo_job.new(storage.job_index, station_surface_index, "cargo", worker)
    storage.jobs[storage.job_index].state = "setup"
    storage.jobs[storage.job_index].destination_station = station
    table.insert(storage.jobs[storage.job_index].task_positions, station.position)
    storage.jobs[storage.job_index].required_items = items_to_fullfill
    storage.job_proc_trigger = true -- start job operations
    return true
end

-- this function checks if another station can provide the items being requested
function cargo_job:roam_stations()
    local current_items = util_func.convert_to_item_list(self.worker_inventory.get_contents())
    local current_requests = util_func.convert_to_item_list(self:list_item_requests())
    local surface_stations = util_func.get_service_stations(self.surface_index)
    for _, station in pairs(surface_stations) do
        -- check that the candidate station is not the destination station, then check if the prospective station can provide the items
        if self.destination_station and self.destination_station.valid and (station.unit_number ~= self.destination_station.unit_number) then
            if self:check_roaming_candidate(station, current_items, current_requests) then
                return
            end
        end
    end
end

-- this function will move the constructron to a new station at the start of a job if the home station is the destination station
function cargo_job:move_stations()
    local current_items = util_func.convert_to_item_list(self.worker_inventory.get_contents())
    local current_requests = self.required_items
    local surface_stations = util_func.get_service_stations(self.surface_index)
    for _, station in pairs(surface_stations) do
        -- check that the candidate station is not the destination station, then check if the prospective station can provide the items
        if self.destination_station and self.destination_station.valid and (station.unit_number ~= self.destination_station.unit_number) then
            if self:check_roaming_candidate(station, current_items, current_requests) then
                return
            end
        end
    end
end

function cargo_job:validate_destination_station()
    if not (self.destination_station and self.destination_station.valid) then
        debug_lib.VisualDebugText({"ctron_status.dest_station_invalid"}, self.worker, -1, 1)
        self.worker.autopilot_destination = nil
        self.state = "finishing"
        return false
    end
    return true
end

--===========================================================================--
--  State Logic
--===========================================================================--

function cargo_job:setup()
    if not self:validate_destination_station() then return end
    -- check if cargo can fit in the inventory
    self.empty_slot_count = self.worker_inventory.count_empty_stacks()
    local total_required_slots = util_func.calculate_required_inventory_slot_count(self.required_items)
    if total_required_slots > self.empty_slot_count then
        -- job will not fit in one constructron, split the job to use multiple constructrons
        local divisor = math.ceil(total_required_slots / (self.empty_slot_count - 1))
        for item, value in pairs(self.required_items) do
            for quality, count in pairs(value) do
                self.required_items[item][quality] = math.ceil(count / divisor)
            end
        end
        if divisor > 1 then
            for i = 1, divisor - 1 do
                storage.cargo_index = storage.cargo_index + 1
                storage.cargo_queue[self.surface_index][storage.cargo_index] = {
                    index = storage.cargo_index,
                    station = self.destination_station,
                    items = self.required_items
                }
            end
            cargo_job.process_cargo_job_queue(self.surface_index)
        end
    end
    -- set default ammo request
    self:request_ammo()
    -- check if the home station is not the destination station
    if (self.station.unit_number == self.destination_station.unit_number) then
        debug_lib.VisualDebugText({"ctron_status.trying_diff_station"}, self.worker, -1, 1)
        self:move_stations()
    end
    -- state change
    self.state = "starting"
end

function cargo_job:in_progress()
    if not self:validate_destination_station() then return end
    local worker = self.worker ---@cast worker -nil
    -- check health
    if not self:check_health() then return end
    -- Am I in the correct position?
    local _, task_position = next(self.task_positions)
    if not self:position_check(task_position, 3) then return end
    if not (self.sub_state == "unloading_items") then
        self:deliver_items()
        self.sub_state = "unloading_items"
        self.job_status = "Delivering cargo"
        return
    else
        if not self:check_trash() then
            local trash_items = util_func.convert_to_item_list(self.worker_trash_inventory.get_contents())
            local logistic_network = self.destination_station.logistic_network
            if (logistic_network.all_logistic_robots <= 0) then
                debug_lib.VisualDebugText({"ctron_status.no_logi_robots"}, worker, -0.5, 3)
                return
            end
            if not next(logistic_network.storages) then
                debug_lib.VisualDebugText({"ctron_status.no_logi_storage"}, worker, -0.5, 3)
                return
            else
                for item_name, value in pairs(trash_items) do
                    for quality, count in pairs(value) do
                        local can_drop = logistic_network.select_drop_point({ stack = { name = item_name, count = count, quality = quality }})
                        debug_lib.VisualDebugText({"ctron_status.awaiting_logistics"}, worker, -1, 1)
                        if can_drop then
                            return
                        end
                    end
                end
            end
            return
        end
        local logistic_point = self.worker.get_logistic_point(0) ---@cast logistic_point -nil
        local section = logistic_point.get_section(1)
        section.filters = {}
        self.sub_state = nil
        self.state = "finishing"
    end
end

function cargo_job:deliver_items()
    local station_unit_number = self.destination_station.unit_number
    local slot = 1
    local logistic_point = self.worker.get_logistic_point(0) ---@cast logistic_point -nil
    local section = logistic_point.get_section(1)
    for _, request in pairs(storage.station_requests[station_unit_number]) do
        for item, value in pairs(self.required_items) do
            for quality, count in pairs(value) do
                if (request.name == item) and (request.quality == quality) then
                    request.in_transit_count = request.in_transit_count - count
                    section.set_slot(slot, {
                        value = {
                            name = item,
                            quality = quality,
                        },
                        min = 0,
                        max = 0
                    })
                    slot = slot + 1
                end
            end
        end
    end
end

return cargo_job