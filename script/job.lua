local util_func = require("script/utility_functions")
local debug_lib = require("script/debug_lib")
local collision_mask_util_extended = require("script/collision-mask-util-control")
local pathfinder = require("script/pathfinder")

-- class for jobs
local job = {} ---@class job
job_metatable = { __index = job } ---@type metatable
script.register_metatable("ctron_job_metatable", job_metatable)

function job.new(job_index, surface_index, job_type, worker)
    local instance = setmetatable({}, job_metatable)
    instance.job_index = job_index -- the global index of the job
    instance.state = "setup" -- the state of the job
    instance.sub_state = nil -- secondary state that can be used to achieve something within a particular state
    instance.job_type = job_type -- the type of action the job will take i.e construction
    instance.surface_index = surface_index -- the surface of the job
    instance.chunks = {} -- these are what define task positions and required & trash items
    instance.required_items = {} -- these are the items required to complete the job
    instance.trash_items = {} -- these are the items that is expected after the job completes
    instance.worker = worker -- this is the constructron that will work the job
    instance.worker_inventory = worker.get_inventory(defines.inventory.spider_trunk)
    instance.worker_ammo_slots = worker.get_inventory(defines.inventory.spider_ammo)
    instance.worker_trash_inventory = worker.get_inventory(defines.inventory.spider_trash)
    instance.station = {} -- used as the home point for item requests etc
    instance.task_positions = {} -- positions where the job will act
    -- job telemetry
    instance.last_position = {} -- used to check if the worker is moving
    instance.last_distance = 0 -- used to check if the worker is moving
    instance.mobility_tick = nil -- used to delay mobility checks
    instance.last_robot_positions = {} -- used to check that robots are active and not stuck
    -- job flags
    instance.landfill_job = false -- used to determine if the job should expect landfill
    instance.roboports_enabled = true -- used to flag if roboports are enabled or not
    instance.deffered_tick = nil -- used to delay job start until xyz tick in conjunction with the deffered job state
    -- lock constructron
    global.available_ctron_count[surface_index] = global.available_ctron_count[surface_index] - 1
    util_func.set_constructron_status(worker, 'busy', true)
    -- change selected constructron colour
    util_func.paint_constructron(worker, job_type)
    return instance
end

---@param surface_index uint
---@return LuaEntity?
job.get_worker = function(surface_index)
    for _, constructron in pairs(global.constructrons) do
        if constructron and constructron.valid and (constructron.surface.index == surface_index) and not util_func.get_constructron_status(constructron, 'busy') then
            if not constructron.logistic_cell or not ((constructron.grid.generator_energy > 0) or (constructron.grid.max_solar_energy > 0)) then
                rendering.draw_text {
                    text = "Needs Equipment",
                    target = constructron,
                    filled = true,
                    surface = constructron.surface,
                    time_to_live = 180,
                    target_offset = {0, -1},
                    alignment = "center",
                    color = {r = 255, g = 255, b = 255, a = 255}
                }
            else
                local logistic_cell = constructron.logistic_cell
                local logistic_network = logistic_cell.logistic_network ---@cast logistic_network -nil
                -- check there are no active robots that the unit owns
                if not next(logistic_network.construction_robots) then
                    if logistic_cell.construction_radius > 0 then
                        return constructron
                    else
                        debug_lib.VisualDebugText("Unsuitable roboports!", constructron, -1, 3)
                    end
                else
                    -- move to robots
                    debug_lib.VisualDebugText("Moving to robots", constructron, -1, 3)
                    util_func.set_constructron_status(constructron, 'busy', true)
                    global.job_index = global.job_index + 1
                    global.jobs[global.job_index] = utility_job.new(global.job_index, surface_index, "utility", constructron)
                    global.jobs[global.job_index].state = "robot_collection"
                    global.job_proc_trigger = true
                end
            end
        end
    end
end

function job:get_chunk()
    local chunk_key, chunk = next(global[self.job_type .. "_queue"][self.surface_index])
    -- calculate empty slots
    self.empty_slot_count = self.worker_inventory.count_empty_stacks()
    chunk.midpoint = {x = ((chunk.minimum.x + chunk.maximum.x) / 2), y = ((chunk.minimum.y + chunk.maximum.y) / 2)}
    -- check for chunk overload
    local total_required_slots = util_func.calculate_required_inventory_slot_count(util_func.combine_tables{self.required_items, chunk.required_items, chunk.trash_items})
    if total_required_slots > self.empty_slot_count then
        local divisor = math.ceil(total_required_slots / (self.empty_slot_count - 5)) -- minus 5 slots to account for rounding up of items
        for item, count in pairs(chunk.required_items) do
            chunk.required_items[item] = math.ceil(count / divisor)
        end
        for item, count in pairs(chunk.trash_items) do
            chunk.trash_items[item] = math.ceil(count / divisor)
        end
        -- duplicate the chunk so another constructron will perform the same job
        if divisor > 1 and (self.job_type == "deconstruction") then
            for i = 1, (divisor - 1) do
                global[self.job_type .. "_queue"][self.surface_index][chunk_key .. "-" .. i] = table.deepcopy(chunk)
                global[self.job_type .. "_queue"][self.surface_index][chunk_key .. "-" .. i]["key"] = chunk_key .. "-" .. i
                if (i ~= (divisor - 1)) then
                    global[self.job_type .. "_queue"][self.surface_index][chunk_key .. "-" .. i].skip_chunk_checks = true -- skips chunk_checks in split chunks
                end
            end
            chunk.skip_chunk_checks = true -- skips chunk_checks in split chunks
        end
    end
    self.chunks[chunk_key] = chunk
    self.required_items = util_func.combine_tables{self.required_items, chunk.required_items}
    self.trash_items = util_func.combine_tables{self.trash_items, chunk.trash_items}
    global[self.job_type .. "_queue"][self.surface_index][chunk_key] = nil
end


function job:include_more_chunks(chunk_params, origin_chunk)
    local job_start_delay = global.job_start_delay
    for _, chunk in pairs(chunk_params.chunks) do
        if ((game.tick - chunk.last_update_tick) > job_start_delay) then
            local chunk_midpoint = {x = ((chunk.minimum.x + chunk.maximum.x) / 2), y = ((chunk.minimum.y + chunk.maximum.y) / 2)}
            if (util_func.distance_between(origin_chunk.midpoint, chunk_midpoint) < 160) then -- seek to include chunk in job
                chunk.midpoint = chunk_midpoint
                local merged_items = util_func.combine_tables{chunk_params.required_items, chunk.required_items}
                local merged_trash = util_func.combine_tables{chunk_params.trash_items, chunk.trash_items}
                local total_required_slots = util_func.calculate_required_inventory_slot_count(util_func.combine_tables{merged_items, merged_trash})
                if total_required_slots < chunk_params.empty_slot_count then -- include chunk in the job
                    table.insert(chunk_params.used_chunks, chunk)
                    chunk_params.required_items = merged_items
                    chunk_params.trash_items = merged_trash
                    global[chunk_params.job_type .. "_queue"][chunk_params.surface_index][chunk.key] = nil
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
        chunks = global[self.job_type .. "_queue"][self.surface_index],
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
        pathfinder.set_autopilot(worker, {{position = position, needs_destroy_to_reach = false}})
        return
    end

    -- IDEA: check path start and destination are not colliding before the path request is made

    local path_request_params = {
        start = worker.position,
        goal = position,
        surface = worker.surface,
        force = worker.force,
        bounding_box = {{-5, -5}, {5, 5}},
        path_resolution_modifier = -2,
        radius = 1, -- the radius parameter only works in situations where it is useless. It does not help when a position is not reachable. Instead, we use find_non_colliding_position.
        collision_mask = game.entity_prototypes["constructron_pathing_proxy_1"].collision_mask,
        pathfinding_flags = {cache = false, low_priority = false},
        try_again_later = 0,
        path_attempt = 1
    }

    self.path_request_params = path_request_params

    if distance > 12 then
        if self.pathfinding then return end
        if self.landfill_job and not self.custom_path and (self.state == "in_progress") then
            worker.enable_logistics_while_moving = true
            self:disable_roboports(1)
            global.custom_pathfinder_index = global.custom_pathfinder_index + 1
            global.custom_pathfinder_requests[global.custom_pathfinder_index] = pathfinder.new(position, worker.position, self)
            if not self.custom_path then
                debug_lib.VisualDebugText("Waiting for pathfinder", worker, -0.5, 1)
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
    global.pathfinder_requests[request_id] = self
end

function job:replace_roboports(old_eq, new_eq)
    local grid = self.worker.grid
    if not grid then return end
    local grid_pos = old_eq.position
    local eq_energy = old_eq.energy
    grid.take{ position = old_eq.position }
    local new_set = grid.put{ name = new_eq, position = grid_pos }
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
                self:replace_roboports(eq, (eq.prototype.take_result.name .. "-reduced-" .. size ))
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
        if (global.allowed_items[item_name] == false) then
            item_list[item_name] = nil
        end
    end
    return item_list
end

function job:request_items(item_list)
    local slot = 1
    for item_name, item_count in pairs(item_list) do
        self.worker.set_vehicle_logistic_slot(slot, {
            name = item_name,
            min = item_count,
            max = item_count
        })
        slot = slot + 1
    end
end

function job:check_robot_activity(construction_robots)
    local last_robot_positions = self.last_robot_positions
    local robot_has_moved = false
    for _, robot in pairs(construction_robots) do
        local previous_position = last_robot_positions[robot.unit_number]
        local current_position = robot.position
        if previous_position ~= nil then
            local position_variance = math.sqrt((current_position.x - previous_position.x)^2 + (current_position.y - previous_position.y)^2)
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
            -- update available constructron count
            global.available_ctron_count[surface_index] = global.available_ctron_count[surface_index] - 1
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
    debug_lib.VisualDebugText("No stations found!", self.worker, -0.5, 5)
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
                    area = {chunk.minimum, chunk.maximum},
                    to_be_deconstructed = true,
                    force = {"player", "neutral"}
                }
            elseif self.job_type == "construction" then
                color = "blue"
                entity_filter = {
                    area = {chunk.minimum, chunk.maximum},
                    type = {"entity-ghost", "tile-ghost", "item-request-proxy"},
                    force = "player"
                }
            elseif self.job_type == "upgrade" then
                color = "green"
                entity_filter = {
                    area = {chunk.minimum, chunk.maximum},
                    force = "player",
                    to_be_upgraded = true
                }
            elseif self.job_type == "repair" then
                return -- repairs do not check
            elseif self.job_type == "destroy" then
                color = "black"
                entity_filter = {
                    area = {chunk.minimum, chunk.maximum},
                    force = "enemy",
                    is_military_target = true,
                    type = {"unit-spawner", "turret"}
                }
            end
            local surface = game.surfaces[chunk.surface]
            debug_lib.draw_rectangle(chunk.minimum, chunk.maximum, surface, color, true, 600)
            local entities = surface.find_entities_filtered(entity_filter) or {}
            if next(entities) then
                debug_lib.DebugLog('added ' .. #entities .. ' entity for ' .. self.job_type .. '.')
                for _, entity in ipairs(entities) do
                    global[self.job_type ..'_index'] = global[self.job_type ..'_index'] + 1
                    global[self.job_type ..'_entities'][global[self.job_type ..'_index']] = entity
                end
                global[self.job_type .. '_tick'] = game.tick
                global.entity_proc_trigger = true -- there is something to do start processing
            end
        end
    end
end

-- method to remove all requests of a job from a combinator
function job:remove_combinator_requests(items)
    for item, value in pairs(items) do
        util_func.update_combinator(self.station, item, (value.count * -1))
    end
end


-- this method validates that the worker has roboport euipment
function job:validate_logisitics()
    local worker = self.worker ---@cast worker -nil
    if not (worker.logistic_cell and worker.logistic_cell.logistic_network) then
        debug_lib.VisualDebugText("Missing roboports in equipment grid!", worker, -0.5, 5)
        return false
    end
    return true
end

-- this function checks if the worker is in the correct position
function job:position_check(position, distance)
    local worker = self.worker ---@cast worker -nil
    local distance_from_pos = util_func.distance_between(worker.position, position)
    if distance_from_pos > distance then
        debug_lib.VisualDebugText("Moving to position", worker, -1, 1)
        if not worker.autopilot_destination then
            if not self.path_request_id then
                self:move_to_position(position)
            end
        else
            if not self:mobility_check() then
                debug_lib.VisualDebugText("Stuck!", worker, -2, 1)
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
        debug_lib.VisualDebugText("Fleeing!", worker, -0.5, 1)
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
    local current_requests = {}
    for i = 1, worker.request_slot_count do
        local request = worker.get_vehicle_logistic_slot(i)
        if request and request.name then
            current_requests[request.name] = {
                count = request.max,
                slot = i
            }
        end
    end
    return current_requests
end

-- this function checks current requests against the items in the workers inventory
function job:check_item_request_fulfillment(current_requests, current_items)
    local is_fulfilled = true
    for request_name, value in pairs(current_requests) do
        local supply_check = (((current_items[request_name] or 0) >= value.count) and ((current_items[request_name] or 0) <= value.count))
        if supply_check then
            current_items[request_name] = nil
            self.worker.clear_vehicle_logistic_slot(value.slot)
        else
            is_fulfilled = false
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
function job:balance_ammunition(ammo_slots, ammunition)
    if not ammunition then return end
    if not ammunition[global.ammo_name[self.surface_index]] then return end
    local ammo_count = ammunition[global.ammo_name[self.surface_index]]
    local ammo_per_slot = math.ceil(ammo_count / #ammo_slots)
    for i = 1, #ammo_slots do
        local slot = ammo_slots[i]
        if slot then
            slot.clear()
            slot.set_stack({name = global.ammo_name[self.surface_index], count = ammo_per_slot})
        end
    end
end

-- this function checks if the requested items are available in the stations logistic network
function job:check_items_are_available(current_requests)
    if global.stations_count[(self.surface_index)] <= 1 then return end
    -- check if current station network can provide
    local logistic_network = self.station.logistic_network
    for request_name, value in pairs(current_requests) do
        if logistic_network.can_satisfy_request(request_name, value.count, true) then
            return true
        end
    end
    return false
end

-- this function checks if another station can provide the items being requested
function job:roam_stations(current_requests)
    local surface_stations = util_func.get_service_stations(self.surface_index)
    for _, station in pairs(surface_stations) do
        if self:check_roaming_candidate(station, current_requests) then
            return
        end
    end
end

function job:check_roaming_candidate(station, current_requests)
    local worker = self.worker ---@cast worker -nil
    if not station and station.valid then return end
    local station_logistic_network = station.logistic_network
    if not station_logistic_network then return end
    for request_name, value in pairs(current_requests) do
        if station_logistic_network.can_satisfy_request(request_name, value.count, true) then
            debug_lib.VisualDebugText("Trying a different station", worker, 0, 5)
            self:remove_combinator_requests(current_requests) -- remove all requests from circuit
            global.constructron_requests[worker.unit_number].station = station -- update request station
            self.sub_state = nil
            self.station = station
            return true
        end
    end
end

function job:set_logistic_cell()
    self.worker_logistic_cell = self.worker.logistic_cell
    return self.worker_logistic_cell
end

function job:set_logistic_network()
    self.worker_logistic_network = self.worker.logistic_cell.logistic_network
    return self.worker_logistic_network
end





--===========================================================================--
--  Job Execution
--===========================================================================--

function job:execute(job_index)
    -- validate worker and station
    if not self:validate_worker() or not self:validate_station() then
        if not game.surfaces[self.surface_index] then
            global.jobs[job_index] = nil
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
    local worker = self.worker ---@cast worker -nil
    -- calculate chunk build positions
    for _, chunk in pairs(self.chunks) do
        debug_lib.draw_rectangle(chunk.minimum, chunk.maximum, self.surface_index, "yellow", false, 3600)
        local positions = util_func.calculate_construct_positions({chunk.minimum, chunk.maximum}, worker.logistic_cell.construction_radius * 0.95) -- 5% tolerance for roboport range
        for _, position in ipairs(positions) do
            debug_lib.VisualDebugCircle(position, self.surface_index, "yellow", 0.5, 3600)
            table.insert(self.task_positions, position)
        end
        if chunk.required_items["landfill"] then
            self.landfill_job = true
        end
    end
    -- set default ammo request
    if global.ammo_count[self.surface_index] > 0 and (worker.name ~= "constructron-rocket-powered") then
        self.required_items[global.ammo_name[self.surface_index]] = global.ammo_count[self.surface_index]
    end
    -- state change
    self.state = "starting"
end

function job:starting()
    local worker = self.worker ---@cast worker -nil
    -- Am I in the correct position?
    if not self:position_check(self.station.position, 10) then return end
    -- set combinator station
    global.constructron_requests[worker.unit_number].station = self.station
    -- Is the logistic network ready?
    local logistic_network = self.station.logistic_network
    if logistic_network.all_logistic_robots == 0 then
        debug_lib.VisualDebugText("No logistic robots in network", self.worker, -0.5, 3)
        return
    end
    -- request items / check inventory
    local inventory_items = self.worker_inventory.get_contents() -- spider inventory contents
    local ammunition = self.worker_ammo_slots.get_contents() -- ammo inventory contents
    local current_items = util_func.combine_tables({inventory_items, ammunition})
    if not (self.sub_state == "items_requested") then
        local item_request_list = table.deepcopy(self.required_items)
        -- check inventory for unwanted items
        for item, _ in pairs(current_items) do
            if not self.required_items[item] then
                item_request_list[item] = 0
            end
        end
        -- check ammo slots for unwanted items
        for item, _ in pairs(ammunition) do
            if item ~= global.ammo_name[self.surface_index] then
                item_request_list[item] = 0
            end
        end
        item_request_list = self:check_items_are_allowed(item_request_list)
        self:request_items(item_request_list)
        self.sub_state = "items_requested"
        self.request_tick = game.tick
        return
    else
        -- populate current requests
        local current_requests = self:list_item_requests()
        -- check if there are any items incoming
        local requester_point = worker.get_logistic_point(0) ---@cast requester_point -nil
        if next(requester_point.targeted_items_deliver) then return end
        -- check if requested items have been delivered
        if not self:check_item_request_fulfillment(current_requests, current_items) then
            debug_lib.VisualDebugText("Awaiting logistics", worker, -1, 1)
            -- station roaming
            local ticks = (game.tick - self.request_tick)
            if not (ticks > 900) then return end
            -- check items are available in the network
            if self:check_items_are_available(current_requests) then return end
            -- attempt to roam to another station
            self:roam_stations(current_requests)
            return
        end
        -- check trash has been taken
        if not self:check_trash() then
            -- IDEA: roam if unable to dump trash
            return
        end
    end
    -- divide ammo evenly between slots
    self:balance_ammunition(self.worker_ammo_slots, ammunition)
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

    local logistic_cell = self.worker_logistic_cell or self:set_logistic_cell()
    local logistic_network = self.worker_logistic_network or self:set_logistic_network()

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

function job:finishing()
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
        if global.queue_proc_trigger then
            item_request[global.desired_robot_name[self.surface_index]] = nil
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
    if not global.queue_proc_trigger and (global.constructrons_count[self.surface_index] > 10) then
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
    util_func.update_combinator(self.station, "constructron_pathing_proxy_1", 0) -- TODO: fix this
    -- change selected constructron colour
    util_func.paint_constructron(worker, 'idle')

    -- release vassals
    for _, vassal_job in pairs((self.vassal_jobs or {})) do
        vassal_job.state = "finishing"
    end
    -- remove job from list
    global.jobs[self.job_index] = nil
    debug_lib.VisualDebugText("Job complete!", worker, -1, 1)
end

function job:deffered()
    -- TODO: you know what to do
end

function job:specific_action()
    game.print("Specific action not defined. You should not be seeing this message!")
end

return job