local util_func = require("script/utility_functions")
local debug_lib = require("script/debug_lib")
local pathfinder = require("script/pathfinder")

-- class for jobs
local job = {} ---@class job
job_metatable = { __index = job } ---@type metatable
script.register_metatable("ctron_job_metatable", job_metatable)

function job.new(job_index, surface_index, job_type, worker)
    local instance = setmetatable({}, job_metatable)
    instance.job_index = job_index         -- the global index of the job
    instance.state = "setup"               -- the state of the job
    instance.sub_state = nil               -- secondary state that can be used to achieve something within a particular state
    instance.job_type = job_type           -- the type of action the job will take i.e construction
    instance.surface_index = surface_index -- the surface of the job
    instance.chunks = {}                   -- these are what define task positions and required & trash items
    instance.required_items = {}           -- these are the items required to complete the job
    instance.trash_items = {}              -- these are the items that is expected after the job completes
    instance.worker = worker               -- this is the constructron that will work the job
    instance.worker_inventory = worker.get_inventory(defines.inventory.spider_trunk)
    instance.worker_ammo_slots = worker.get_inventory(defines.inventory.spider_ammo)
    instance.worker_trash_inventory = worker.get_inventory(defines.inventory.spider_trash)
    instance.station = {}              -- used as the home point for item requests etc
    instance.task_positions = {}       -- positions where the job will act
    -- job telemetry
    instance.last_position = {}        -- used to check if the worker is moving
    instance.last_distance = 0         -- used to check if the worker is moving
    instance.mobility_tick = nil       -- used to delay mobility checks
    instance.last_robot_positions = {} -- used to check that robots are active and not stuck
    instance.job_status = "New"        -- used to display the current job status in the UI
    -- job flags
    instance.landfill_job = false      -- used to determine if the job should expect landfill
    instance.roboports_enabled = true  -- used to flag if roboports are enabled or not
    instance.deffered_tick = nil       -- used to delay job start until xyz tick in conjunction with the deffered job state
    -- lock constructron
    util_func.set_constructron_status(worker, 'busy', true)
    -- change selected constructron colour
    util_func.paint_constructron(worker, job_type)
    return instance
end

---@param surface_index uint
---@return LuaEntity?
job.get_worker = function(surface_index)
    for _, constructron in pairs(storage.constructrons) do
        if constructron and constructron.valid and (constructron.surface.index == surface_index) and not util_func.get_constructron_status(constructron, 'busy') then
            if job.check_equipment(constructron) then -- TODO: add  (constructron.grid.generator_energy & max_solar_energy)
                local logistic_cell = constructron.logistic_cell
                local logistic_network = logistic_cell.logistic_network ---@cast logistic_network -nil
                -- check there are no active robots that the unit owns
                if not next(logistic_network.construction_robots) then
                    if logistic_cell.construction_radius > 0 then
                        return constructron
                    else
                        debug_lib.VisualDebugText({"ctron_status.bad_roboports"}, constructron, -1, 3)
                    end
                else
                    -- create a utility job and move to robots
                    debug_lib.VisualDebugText({"ctron_status.moving_to_robots"}, constructron, -1, 3)
                    storage.job_index = storage.job_index + 1
                    storage.jobs[storage.job_index] = utility_job.new(storage.job_index, surface_index, "utility", constructron)
                    storage.jobs[storage.job_index].state = "robot_collection"
                end
            end
        end
    end
end

---@param constructron LuaEntity
---@return boolean
job.check_equipment = function(constructron)
    if not constructron.logistic_cell then
        rendering.draw_text {
            text = {"ctron_status.missing_roboports"},
            target = constructron,
            filled = true,
            surface = constructron.surface,
            time_to_live = 180,
            target_offset = { 0, -1 },
            alignment = "center",
            color = { r = 255, g = 255, b = 255, a = 255 }
        }
        return false
    end
    if not ((constructron.grid.get_generator_energy() > 0) or (constructron.grid.max_solar_energy > 0)) then
        rendering.draw_text {
            text = {"ctron_status.missing_power"},
            target = constructron,
            filled = true,
            surface = constructron.surface,
            time_to_live = 180,
            target_offset = { 0, -1 },
            alignment = "center",
            color = { r = 255, g = 255, b = 255, a = 255 }
        }
        return false
    end
    return true
end

-- idea for mass entity handling
-- local function get_upgrade_quality(target, chunk)
--     local inventory = game.create_inventory.insert({name = "blueprint"})
--     inventory[1].create_blueprint{
--         surface = 1,
--         force = "player",
--         area = {chunk.minimum, chunk.maximum},
--     }

--     local blueprint_entities = inventory[1].get_blueprint_entities() or {}
--     assert(#blueprint_entities == 1, 'time to check for name and position.')

--     inventory.destroy()
--     return blueprint_entities[1].quality -- string
-- end

function job:get_chunk()
    local chunk_key, chunk = next(storage[self.job_type .. "_queue"][self.surface_index])
    -- calculate empty slots
    self.empty_slot_count = self.worker_inventory.count_empty_stacks()
    chunk.midpoint = { x = ((chunk.minimum.x + chunk.maximum.x) / 2), y = ((chunk.minimum.y + chunk.maximum.y) / 2) }
    -- check for chunk overload
    local total_required_slots = util_func.calculate_required_inventory_slot_count(util_func.combine_tables { self.required_items, chunk.required_items, chunk.trash_items })
    if total_required_slots > self.empty_slot_count then
        local divisor = math.ceil(total_required_slots / (self.empty_slot_count - 5)) -- minus 5 slots to account for rounding up of items and trash
        for item, value in pairs(chunk.required_items) do
            for quality, count in pairs(value) do
                chunk.required_items[item] = {
                    [quality] = math.ceil(count / divisor)
                }
            end
        end
        for item, value in pairs(chunk.trash_items) do
            for quality, count in pairs(value) do
                chunk.trash_items[item] = {
                    [quality] = math.ceil(count / divisor)
                }
            end
        end
        -- duplicate the chunk so another constructron will perform the same job
        if divisor > 1 and (self.job_type == "deconstruction") then
            for i = 1, (divisor - 1) do
                storage[self.job_type .. "_queue"][self.surface_index][chunk_key .. "-" .. i] = table.deepcopy(chunk)
                storage[self.job_type .. "_queue"][self.surface_index][chunk_key .. "-" .. i]["key"] = chunk_key .. "-" .. i
                if (i ~= (divisor - 1)) then
                    storage[self.job_type .. "_queue"][self.surface_index][chunk_key .. "-" .. i].skip_chunk_checks = true -- skips chunk_checks in split chunks
                end
            end
            chunk.skip_chunk_checks = true -- skips chunk_checks in split chunks
        end
    end
    self.chunks[chunk_key] = chunk
    self.required_items = util_func.combine_tables { self.required_items, chunk.required_items }
    self.trash_items = util_func.combine_tables { self.trash_items, chunk.trash_items }
    storage[self.job_type .. "_queue"][self.surface_index][chunk_key] = nil
end

function job:include_more_chunks(chunk_params, origin_chunk)
    local job_start_delay = storage.job_start_delay
    for _, chunk in pairs(chunk_params.chunks) do
        if ((game.tick - chunk.last_update_tick) > job_start_delay) then
            local chunk_midpoint = { x = ((chunk.minimum.x + chunk.maximum.x) / 2), y = ((chunk.minimum.y + chunk.maximum.y) / 2) }
            if (util_func.distance_between(origin_chunk.midpoint, chunk_midpoint) < 160) then -- seek to include chunk in job
                chunk.midpoint = chunk_midpoint
                local merged_items = util_func.combine_tables { chunk_params.required_items, chunk.required_items }
                local merged_trash = util_func.combine_tables { chunk_params.trash_items, chunk.trash_items }
                local total_required_slots = util_func.calculate_required_inventory_slot_count(util_func.combine_tables { merged_items, merged_trash })
                if total_required_slots < chunk_params.empty_slot_count then -- include chunk in the job
                    table.insert(chunk_params.used_chunks, chunk)
                    chunk_params.required_items = merged_items
                    chunk_params.trash_items = merged_trash
                    storage[chunk_params.job_type .. "_queue"][chunk_params.surface_index][chunk.key] = nil
                    return self:include_more_chunks(chunk_params, chunk)
                end
            end
        end
    end
    return chunk_params.used_chunks, chunk_params.required_items
end

function job:find_chunks_in_proximity()
    -- merge chunks in proximity to each other into one job
    local _, origin_chunk = next(self.chunks)
    local chunk_params = {
        chunks = storage[self.job_type .. "_queue"][self.surface_index],
        job_type = self.job_type,
        surface_index = self.surface_index,
        empty_slot_count = self.empty_slot_count,
        used_chunks = {},
        required_items = self.required_items,
        trash_items = self.trash_items
    }
    local combined_chunks, required_items = self:include_more_chunks(chunk_params, origin_chunk)
    for _, v in pairs(combined_chunks) do
        if not self.chunks[v.key] then
            self.chunks[v.key] = v
        end
    end
    self.required_items = required_items
end

function job:move_to_position(position)
    local worker = self.worker
    if not worker or not worker.valid then return end
    local distance = util_func.distance_between(worker.position, position)
    worker.grid.inhibit_movement_bonus = (distance < 32)

    if worker.name == "constructron-rocket-powered" then
        pathfinder.set_autopilot(worker, { { position = position, needs_destroy_to_reach = false } })
        return
    end

    -- IDEA: check path start and destination are not colliding before the path request is made

    local path_request_params = {
        start = worker.position,
        goal = position,
        surface = worker.surface,
        force = worker.force,
        bounding_box = { { -5, -5 }, { 5, 5 } },
        path_resolution_modifier = -2,
        radius = 1, -- the radius parameter only works in situations where it is useless. It does not help when a position is not reachable. Instead, we use find_non_colliding_position.
        collision_mask = prototypes.entity["constructron_pathing_proxy_1"].collision_mask,
        pathfinding_flags = { cache = false, low_priority = false },
        try_again_later = 0,
        path_attempt = 1,
        max_gap_size = 12
    }

    self.path_request_params = path_request_params

    if distance > 12 then
        if self.pathfinding then return end
        if self.landfill_job and not self.custom_path and (self.state == "in_progress") then
            worker.enable_logistics_while_moving = true
            self:disable_roboports(1)
            storage.custom_pathfinder_index = storage.custom_pathfinder_index + 1
            storage.custom_pathfinder_requests[storage.custom_pathfinder_index] = pathfinder.new(position, worker.position, self)
            if not self.custom_path then
                debug_lib.VisualDebugText({"ctron_status.awaiting_pathfinder"}, worker, -0.5, 1)
                return
            end
            self:request_path()
        else
            self:request_path()
        end
    else
        worker.autopilot_destination = position -- does not use path finder!
    end
end

function job:request_path()
    local request_id = self.worker.surface.request_path(self.path_request_params) -- request the path from the game
    debug_lib.VisualDebugLine(self.worker.position, self.path_request_params.goal, self.worker.surface, "blue", 600)
    self.path_request_id = request_id
    storage.pathfinder_requests[request_id] = self
end

function job:replace_roboports(old_eq, new_eq)
    local grid = self.worker.grid
    if not grid then return end
    local grid_pos = old_eq.position
    local eq_energy = old_eq.energy
    grid.take { position = old_eq.position }
    local new_set = grid.put { name = new_eq, position = grid_pos }
    if new_set then
        new_set.energy = eq_energy
    end
end

function job:disable_roboports(size) -- doesn't really disable them, it sets the size of that cell
    local grid = self.worker.grid
    if not grid then return end
    self.roboports_enabled = false
    for _, eq in next, grid.equipment do
        if eq.type == "roboport-equipment" and not (eq.prototype.logistic_parameters.construction_radius == size) then
            if not string.find(eq.name, "%-reduced%-" .. size) then
                self:replace_roboports(eq, (eq.prototype.take_result.name .. "-reduced-" .. size))
            end
        end
    end
end

function job:enable_roboports() -- doesn't really enable roboports, it resets the equipment back to the original
    local grid = self.worker.grid
    if not grid then return end
    self.roboports_enabled = true
    for _, eq in next, grid.equipment do
        if eq.type == "roboport-equipment" then
            self:replace_roboports(eq, eq.prototype.take_result.name)
        end
    end
end

-- this function checks for items that are not allowed. usually because they are not craftable by the player
function job:check_items_are_allowed(item_list)
    for item_name in pairs(item_list) do
        if (storage.allowed_items[item_name] == false) then
            item_list[item_name] = nil
        end
    end
    return item_list
end

function job:request_items(item_list)
    self.job_status = "Requesting items"
    local slot = 1
    local logistic_point = self.worker.get_logistic_point(0) ---@cast logistic_point -nil
    local section = logistic_point.get_section(1)
    -- disable trash unrequested
    if logistic_point.trash_not_requested then
        logistic_point.trash_not_requested = false
    end
    -- set item request filters
    section.filters = {}
    for item_name, value in pairs(item_list) do
        if prototypes.item[item_name] then
            for quality, count in pairs(value) do
                section.set_slot(slot, {
                    value = {
                        name = item_name,
                        quality = quality,
                    },
                    min = count,
                    max = count
                })
                slot = slot + 1
            end
        end
    end
end

function job:check_robot_activity(construction_robots)
    local last_robot_positions = self.last_robot_positions
    local robot_has_moved = false
    for _, robot in pairs(construction_robots) do
        local previous_position = last_robot_positions[robot.unit_number]
        local current_position = robot.position
        if previous_position ~= nil then
            local position_variance = math.sqrt((current_position.x - previous_position.x) ^ 2 + (current_position.y - previous_position.y) ^ 2)
            if position_variance > 0.1 then -- has the robot moved?
                robot_has_moved = true
                self.last_robot_positions[robot.unit_number] = current_position
                break
            else
                for _, bot in pairs(construction_robots) do
                    self.last_robot_positions[bot.unit_number] = bot.position
                end
                break
            end
        else
            self.last_robot_positions[robot.unit_number] = current_position
            robot_has_moved = true
            break
        end
    end
    return robot_has_moved
end

function job:validate_worker()
    if self.worker and self.worker.valid then
        return true
    else
        local surface_index = self.surface_index
        self.worker = job.get_worker(surface_index)
        if self.worker and self.worker.valid then
            -- lock constructron
            util_func.set_constructron_status(self.worker, 'busy', true)
            -- change selected constructron colour
            util_func.paint_constructron(self.worker, self.job_type)
            -- reset job
            self.state = "setup"
            self.worker_logistic_cell = self.worker.logistic_cell
            self.worker_logistic_network = self.worker.logistic_cell.logistic_network
            self.worker_inventory = self.worker.get_inventory(defines.inventory.spider_trunk)
            self.worker_ammo_slots = self.worker.get_inventory(defines.inventory.spider_ammo)
            self.worker_trash_inventory = self.worker.get_inventory(defines.inventory.spider_trash)
        else
            return false
        end
    end
end

function job:validate_station()
    if self.station and self.station.valid and self.station.logistic_network then
        return true
    elseif self.worker and self.worker.valid then
        local new_station = util_func.get_closest_service_station(self.worker)
        if new_station and new_station.valid and new_station.logistic_network then
            self.station = new_station
            return true
        else
            local surface_stations = util_func.get_service_stations(self.surface_index)
            for _, station in pairs(surface_stations) do
                if station and station.valid and station.logistic_network then
                    self.station = station
                    return true
                end
            end
        end
    end
    debug_lib.VisualDebugText({"ctron_status.no_stations_found"}, self.worker, -0.5, 5)
    return false
end

function job:mobility_check()
    local game_tick = game.tick
    if not ((game_tick - (self.mobility_tick or 0)) > 180) then
        return true
    end
    local worker = self.worker ---@cast worker -nil
    local last_distance = self.last_distance
    local current_distance = util_func.distance_between(worker.position, worker.autopilot_destination) or 0
    if (worker.speed < 0.05) and last_distance and ((last_distance - current_distance) < 2) and not next(worker.stickers or {}) then -- if movement has not progressed at least two tiles
        return false -- is not mobile
    end
    self.last_distance = current_distance
    self.mobility_tick = game_tick
    return true -- is mobile
end

function job:check_chunks()
    local color
    local entity_filter = {}
    for _, chunk in pairs(self.chunks) do
        if not chunk.skip_chunk_checks then
            if (chunk.minimum.x == chunk.maximum.x) and (chunk.minimum.y == chunk.maximum.y) then
                chunk.minimum.x = chunk.minimum.x - 1
                chunk.minimum.y = chunk.minimum.y - 1
                chunk.maximum.x = chunk.maximum.x + 1
                chunk.maximum.y = chunk.maximum.y + 1
            end
            if self.job_type == "deconstruction" then
                color = "red"
                entity_filter = {
                    area = { chunk.minimum, chunk.maximum },
                    to_be_deconstructed = true,
                    force = { "player", "neutral" }
                }
            elseif self.job_type == "construction" then
                color = "blue"
                entity_filter = {
                    area = { chunk.minimum, chunk.maximum },
                    type = { "entity-ghost", "tile-ghost", "item-request-proxy" },
                    force = "player"
                }
            elseif self.job_type == "upgrade" then
                color = "green"
                entity_filter = {
                    area = { chunk.minimum, chunk.maximum },
                    force = "player",
                    to_be_upgraded = true
                }
            elseif self.job_type == "repair" then
                return -- repairs do not check
            elseif self.job_type == "destroy" then
                color = "black"
                entity_filter = {
                    area = { chunk.minimum, chunk.maximum },
                    force = "enemy",
                    is_military_target = true,
                    type = { "unit-spawner", "turret" }
                }
            end
            local surface = game.surfaces[chunk.surface]
            debug_lib.draw_rectangle(chunk.minimum, chunk.maximum, surface, color, true, 600)
            local entities = surface.find_entities_filtered(entity_filter) or {}
            if next(entities) then
                debug_lib.DebugLog('added ' .. #entities .. ' entity for ' .. self.job_type .. '.')
                for _, entity in ipairs(entities) do
                    storage[self.job_type .. '_index'] = storage[self.job_type .. '_index'] + 1
                    storage[self.job_type .. '_entities'][storage[self.job_type .. '_index']] = entity
                end
                storage[self.job_type .. '_tick'] = game.tick
                storage.entity_proc_trigger = true -- there is something to do start processing
            end
        end
    end
end

function job:validate_logisitics()
    local worker = self.worker ---@cast worker -nil
    -- validate logisitic cell (constructrion has roboports)
    if not (self.worker_logistic_cell and self.worker_logistic_cell.valid) then
        if not worker.logistic_cell then
            debug_lib.VisualDebugText({"ctron_status.missing_roboports"}, worker, -0.5, 5)
            return false
        end
        self.worker_logistic_cell = self.worker.logistic_cell
    end
    -- validate logisitic network (constructrion has roboports)
    if not (self.worker_logistic_network and self.worker_logistic_network.valid) then
        if not self.worker_logistic_cell.logistic_network then
            debug_lib.VisualDebugText({"ctron_status.missing_roboports"}, worker, -0.5, 5)
            return false
        end
        self.worker_logistic_network = self.worker_logistic_cell.logistic_network
    end
    -- validate that there is a logisitic section available, if not create one
    local logistic_point = worker.get_logistic_point(0) ---@cast logistic_point -nil
    local section = logistic_point.get_section(1)
    if not section then
        logistic_point.add_section()
    end
    return true
end

-- this function checks if the worker is in the correct position
function job:position_check(position, distance)
    local worker = self.worker ---@cast worker -nil
    local distance_from_pos = util_func.distance_between(worker.position, position)
    if distance_from_pos > distance then
        debug_lib.VisualDebugText({"ctron_status.ctron_status.moving_to_pos"}, worker, -1, 1)
        self.job_status = "Moving to position"
        if not worker.autopilot_destination then
            if not self.path_request_id then
                self:move_to_position(position)
            end
        else
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

-- this function checks if the workers health is low
function job:check_health()
    local worker = self.worker ---@cast worker -nil
    local health = worker.get_health_ratio()
    if health < 0.6 then
        debug_lib.VisualDebugText({"ctron_status.fleeing"}, worker, -0.5, 1)
        -- set the station as an iterim retreat target but request a path to take over
        worker.autopilot_destination = self.station.position
        self:move_to_position(self.station.position)
        self:check_chunks()
        self.state = "finishing"
        self.sub_state = "low_health"
        return false
    end
    return true
end

-- this function lists the current item requests of the worker
function job:list_item_requests()
    local worker = self.worker ---@cast worker -nil
    local logistic_point = worker.get_logistic_point(0) ---@cast logistic_point -nil
    local section = logistic_point.get_section(1)
    return section.filters or {}
end

-- this function checks current requests against the items in the workers inventory
---@return boolean
function job:check_item_request_fulfillment()
    local worker = self.worker ---@cast worker -nil
    local logistic_point = worker.get_logistic_point(0) ---@cast logistic_point -nil
    local section = logistic_point.get_section(1)
    local is_fulfilled = true
    local inventory_items = util_func.convert_to_item_list(self.worker_inventory.get_contents()) -- spider inventory contents
    local ammunition = util_func.convert_to_item_list(self.worker_ammo_slots.get_contents()) -- ammo inventory contents
    local current_requests = util_func.convert_to_item_list(self:list_item_requests())
    local current_items = util_func.combine_tables({ inventory_items, ammunition })
    for item_name, value in pairs(current_requests) do
        for quality, count in pairs(value) do
            current_items[item_name] = current_items[item_name] or {}
            local supply_check = (((current_items[item_name][quality] or 0) >= count) and ((current_items[item_name][quality] or 0) <= count))
            if supply_check then
                for index, filter in pairs(section.filters) do
                    local filter_value = filter.value
                    if filter_value then
                        if (filter_value.name == item_name) and (filter_value.quality == quality) then
                            section.clear_slot(index)
                        end
                    end
                end
            else
                is_fulfilled = false
            end
        end
    end
    return is_fulfilled
end

-- this function checks that the trash inventory is empty
function job:check_trash()
    local trash_items = self.worker_trash_inventory.get_contents()
    if next(trash_items) then
        return false
    end
    return true
end

-- this function balances the ammunition amount accross the workers rocket launchers
function job:balance_ammunition()
    local ammunition = util_func.convert_to_item_list(self.worker_ammo_slots.get_contents()) -- ammo inventory contents
    if not next(ammunition) then return end
    -- if not ammunition[storage.ammo_name[self.surface_index]] then return end
    local ammo_name, value = next(ammunition)
    local quality, ammo_count = next(value)
    -- local ammo_count = ammunition[ammo_name][quality]
    local ammo_slots = self.worker_ammo_slots ---@cast ammo_slots -nil
    local ammo_per_slot = math.ceil(ammo_count / #ammo_slots)
    for i = 1, #ammo_slots do
        local slot = ammo_slots[i]
        if slot then
            slot.clear()
            slot.set_stack({ name = ammo_name, quality = quality, count = ammo_per_slot })
        end
    end
end

-- this function checks if the requested items are available in the job stations logistic network
---@return boolean
function job:check_items_are_available()
    local current_requests = util_func.convert_to_item_list(self:list_item_requests())
    local logistic_network = self.station.logistic_network
    for request_name, value in pairs(current_requests) do
        for quality, count in pairs(value) do
            if logistic_network.can_satisfy_request({name = request_name, quality = quality}, count, true) then
                return true
            end
        end
    end
    return false
end

-- this function checks if another station can provide the items being requested
function job:roam_stations()
    local current_items = util_func.convert_to_item_list(self.worker_inventory.get_contents())
    local current_requests = util_func.convert_to_item_list(self:list_item_requests())
    local surface_stations = util_func.get_service_stations(self.surface_index)
    for _, station in pairs(surface_stations) do
        if self:check_roaming_candidate(station, current_items, current_requests) then
            return
        end
    end
end

---@param station LuaEntity
---@param current_requests table
---@return boolean
function job:check_roaming_candidate(station, current_items, current_requests)
    if not station and station.valid then return false end
    local station_logistic_network = station.logistic_network
    if not station_logistic_network then return false end
    for request_name, value in pairs(current_requests) do
        for quality, count in pairs(value) do
            local needed_count = count
            if current_items[request_name] and current_items[request_name][quality] then
                needed_count = count - current_items[request_name][quality]
            end
            if station_logistic_network.can_satisfy_request({name = request_name, quality = quality}, needed_count, true) then
                debug_lib.VisualDebugText({"ctron_status.trying_diff_station"}, self.worker, 0, 5)
                self.sub_state = nil
                self.station = station
                return true
            end
        end
    end
    return false
end

function job:randomize_idle_position()
    if self:check_for_queued_jobs() then return end
    if not (storage.constructrons_count[self.surface_index] > 10) then return end
    local worker = self.worker ---@cast worker -nil
    local stepdistance = 5 + math.random(5)
    local alpha = math.random(360)
    local offset = { x = (math.cos(alpha) * stepdistance), y = (math.sin(alpha) * stepdistance) }
    local new_position = { x = (worker.position.x + offset.x), y = (worker.position.y + offset.y) }
    worker.autopilot_destination = new_position
end

---checks if there are any more jobs to do
---@return boolean
function job:check_for_queued_jobs()
    for _, job_type in pairs(storage.job_types) do
        if next(storage[job_type .. "_queue"][self.surface_index]) then
            return true
        end
    end
    return false
end

function job:clear_items()
    local worker = self.worker ---@cast worker -nil
    if not (self.sub_state == "items_requested") then
        local inventory_items = util_func.convert_to_item_list(self.worker_inventory.get_contents())
        local item_request = {}
        for item, value in pairs(inventory_items) do
            for quality, count in pairs(value) do
                item_request[item] = {
                    [quality] = 0
                }
            end
        end
        if self:check_for_queued_jobs() then
            local robot = storage.desired_robot_name[self.surface_index]
            if item_request[robot.name] and item_request[robot.name][robot.quality] then
                item_request[robot.name][robot.quality] = nil
            end
        end
        self:request_items(item_request)
        self.job_status = "Clearing inventory"
        self.sub_state = "items_requested"
        self.request_tick = game.tick
        return false
    else
        -- check trash has been taken
        local trash_items = util_func.convert_to_item_list(self.worker_trash_inventory.get_contents())
        if next(trash_items) then
            local logistic_network = self.station.logistic_network
            if (logistic_network.all_logistic_robots <= 0) then
                debug_lib.VisualDebugText({"ctron_status.no_logi_robots"}, worker, -0.5, 3)
            end
            if not next(logistic_network.storages) then
                debug_lib.VisualDebugText({"ctron_status.no_logi_storage"}, worker, -0.5, 3)
            else
                for item_name, value in pairs(trash_items) do
                    for quality, count in pairs(value) do
                        local can_drop = logistic_network.select_drop_point({ stack = { name = item_name, count = count, quality = quality }})
                        debug_lib.VisualDebugText({"ctron_status.awaiting_logistics"}, worker, -1, 1)
                        if can_drop then
                            return false
                        end
                    end
                end
            end
            -- check if other station networks can store items
            local surface_stations = util_func.get_service_stations(self.surface_index)
            for _, station in pairs(surface_stations) do
                if station.logistic_network then
                    for item_name, value in pairs(trash_items) do
                        for quality, count in pairs(value) do
                            local can_drop = station.logistic_network.select_drop_point({ stack = { name = item_name, count = count, quality = quality }})
                            debug_lib.VisualDebugText({"ctron_status.awaiting_logistics"}, worker, -1, 1)
                            if can_drop then
                                debug_lib.VisualDebugText({"ctron_status.trying_diff_station"}, worker, 1, 5)
                                self.station = station
                                return false
                            end
                        end
                    end
                end
            end
            return false
        else
            self.sub_state = nil
            self.request_tick = nil
            return true
        end
    end
end

function job:request_ammo()
    if storage.ammo_count[self.surface_index] > 0 and (self.worker.name ~= "constructron-rocket-powered") then
        local ammo = storage.ammo_name[self.surface_index]
        self.required_items[ammo.name] = { [ammo.quality] = storage.ammo_count[self.surface_index] }
    end
end

local landfill_types = {"ice-platform", "foundation", "landfill"}

-- flag the job as a landfill job if certain items are present in the jobs required_items
function job:check_if_landfilling()
    for _, type in ipairs(landfill_types) do
        if self.required_items[type] then
            self.landfill_job = true
            self.landfill_type = type
            break
        end
    end
end

function job:calculate_task_positions()
    local worker = self.worker ---@cast worker -nil
    for _, chunk in pairs(self.chunks) do
        debug_lib.draw_rectangle(chunk.minimum, chunk.maximum, self.surface_index, "yellow", false, 3600)
        local positions = util_func.calculate_construct_positions({ chunk.minimum, chunk.maximum }, worker.logistic_cell.construction_radius * 0.95) -- 5% tolerance for roboport range
        for _, position in ipairs(positions) do
            debug_lib.VisualDebugCircle(position, self.surface_index, "yellow", 0.5, 3600)
            table.insert(self.task_positions, position)
        end
    end
end

---@param item_request_list table
---@return table
function job:inventory_check(item_request_list)
    local inventory_items = util_func.convert_to_item_list(self.worker_inventory.get_contents()) -- spider inventory contents
    local ammunition = util_func.convert_to_item_list(self.worker_ammo_slots.get_contents()) -- ammo inventory contents
    for item_name, value in pairs(inventory_items) do
        for quality, count in pairs(value) do
            if not self.required_items[item_name] then
                item_request_list[item_name] = {
                    [quality] = 0
                }
            elseif not self.required_items[item_name][quality] then
                item_request_list[item_name] = {
                    [quality] = 0
                }
            end
        end
    end
    -- check ammo slots for unwanted items
    for item_name, value in pairs(ammunition) do
        for quality, count in pairs(value) do
            if not self.required_items[item_name] then
                item_request_list[item_name] = {
                    [quality] = 0
                }
            elseif not self.required_items[item_name][quality] then
                item_request_list[item_name] = {
                    [quality] = 0
                }
            end
        end
    end
    return item_request_list
end

function job:check_ammo_count()
    local ammo_count = storage.ammo_count[self.surface_index]
    if ammo_count <= 0 then return true end
    local ammunition = util_func.convert_to_item_list(self.worker_ammo_slots.get_contents())
    local ammo = storage.ammo_name[self.surface_index]
    local ammo_name = ammo.name
    local ammo_quality = ammo.quality
    -- retreat when at 25% of ammo
    if not (ammunition and ammunition[ammo_name] and (ammunition[ammo_name][ammo_quality] > (math.ceil(ammo_count * 25 / 100)))) then
        self.state = "starting"
        return false
    end
    return true
end

--===========================================================================--
--  Job Execution
--===========================================================================--

function job:execute(job_index)
    -- validate worker and station
    if not self:validate_worker() or not self:validate_station() then
        if not game.surfaces[self.surface_index] then
            storage.jobs[job_index] = nil
        end
        return
    end
    -- validate logistics
    if not self:validate_logisitics() then
        -- IDEA: Factorio v2 request equipment
        return
    end
    -- execute job according to state
    self[self.state](self)
end

--===========================================================================--
--  State Logic
--===========================================================================--

function job:setup()
    -- calculate task positions
    self:calculate_task_positions()
    -- request ammo
    self:request_ammo()
    -- check if landfilling
    self:check_if_landfilling()
    -- state change
    self.state = "starting"
end

function job:starting()
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

function job:in_progress()
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

    -- Am I in the correct position?
    local _, task_position = next(self.task_positions)
    if not self:position_check(task_position, 3) then return end

    --===========================================================================--
    --  Common logic
    --===========================================================================--
    local construction_robots = logistic_network.construction_robots

    debug_lib.VisualDebugText({"ctron_status.job_type_" .. self.job_type}, worker, -1, 1)
    self.job_status = "Working"

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

function job:finishing()
    local worker = self.worker ---@cast worker -nil
    worker.enable_logistics_while_moving = false
    if not self:position_check(self.station.position, 10) then return end
    if not self.roboports_enabled then -- enable full roboport range (due to landfil jobs disabling them)
        self:enable_roboports()
    end
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

    -- release vassals
    for _, vassal_job in pairs((self.vassal_jobs or {})) do
        vassal_job.state = "finishing"
    end
    -- remove job from list
    storage.jobs[self.job_index] = nil
    debug_lib.VisualDebugText({"ctron_status.job_complete"}, worker, -1, 1)
end

function job:deffered()
    -- TODO: you know what to do
end

function job:specific_action()
    game.print("Specific action not defined. You should not be seeing this message!")
end

return job
