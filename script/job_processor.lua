
local debug_lib = require("script/debug_lib")
local chunk_util = require("script/chunk_util")
local ctron = require("script/constructron")
local pathfinder = require("script/pathfinder")
local collision_mask_util_extended = require("script/collision-mask-util-control")

local job_proc = {}

local job = {}
job.__index = job
script.register_metatable("job_table", job)

function job_proc.new(job_index, surface_index, job_type, worker)
    local instance = setmetatable({}, job)
    instance.job_index = job_index -- the global index of the job
    instance.state = "new" -- the state of the job
    instance.sub_state = nil -- secondary state that can be used to achieve something within a particular state
    instance.job_type = job_type -- the type of action the job will take i.e construction
    instance.surface_index = surface_index -- the surface of the job
    instance.chunks = {} -- these are what define task positions and required & trash items
    instance.required_items = {} -- these are the items required to complete the job
    instance.trash_items = {} -- these are the items that is expected after the job completes
    instance.worker = worker -- this is the constructron that will work the job
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
    ctron.set_constructron_status(worker, 'busy', true)
    -- change selected constructron colour
    ctron.paint_constructron(worker, job_type)
    return instance
end

function job:get_chunk()
    local chunk_key, chunk = next(global[self.job_type .. "_queue"][self.surface_index])
    -- calculate empty slots
    local inventory = self.worker.get_inventory(defines.inventory.spider_trunk)
    self.empty_slot_count = inventory.count_empty_stacks()
    chunk.midpoint = {x = ((chunk.minimum.x + chunk.maximum.x) / 2), y = ((chunk.minimum.y + chunk.maximum.y) / 2)}
    -- check for chunk overload
    local total_required_slots = job_proc.calculate_required_inventory_slot_count(job_proc.combine_tables{self.required_items, chunk.required_items, chunk.trash_items})
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
    self.required_items = job_proc.combine_tables{self.required_items, chunk.required_items}
    self.trash_items = job_proc.combine_tables{self.trash_items, chunk.trash_items}
    global[self.job_type .. "_queue"][self.surface_index][chunk_key] = nil
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
    local combined_chunks, required_items = job_proc.include_more_chunks(chunk_params, origin_chunk)
    for _, v in pairs(combined_chunks) do
        if not self.chunks[v.key] then
            self.chunks[v.key] = v
        end
    end
    self.required_items = required_items
end

job_proc.include_more_chunks = function(chunk_params, origin_chunk)
    for _, chunk in pairs(chunk_params.chunks) do
        local chunk_midpoint = {x = ((chunk.minimum.x + chunk.maximum.x) / 2), y = ((chunk.minimum.y + chunk.maximum.y) / 2)}
        if (chunk_util.distance_between(origin_chunk.midpoint, chunk_midpoint) < 160) then -- seek to include chunk in job
            chunk.midpoint = chunk_midpoint
            local merged_items = job_proc.combine_tables{chunk_params.required_items, chunk.required_items}
            local merged_trash = job_proc.combine_tables{chunk_params.trash_items, chunk.trash_items}
            local total_required_slots = job_proc.calculate_required_inventory_slot_count(job_proc.combine_tables{merged_items, merged_trash})
            if total_required_slots < chunk_params.empty_slot_count then -- include chunk in the job
                table.insert(chunk_params.used_chunks, chunk)
                chunk_params.required_items = merged_items
                chunk_params.trash_items = merged_trash
                global[chunk_params.job_type .. "_queue"][chunk_params.surface_index][chunk.key] = nil
                return job_proc.include_more_chunks(chunk_params, chunk)
            end
        end
    end
    return chunk_params.used_chunks, chunk_params.required_items
end

function job:move_to_position(position)
    local worker = self.worker
    if not worker or not worker.valid then return end
    local distance = chunk_util.distance_between(worker.position, position)
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
        collision_mask = {"player-layer", "consider-tile-transitions", "colliding-with-tiles-only", "not-colliding-with-itself"},
        pathfinding_flags = {cache = false, low_priority = false},
        try_again_later = 0,
        path_attempt = 1
    }

    if game.active_mods["space-exploration"] then
        local spaceship_collision_layer = collision_mask_util_extended.get_named_collision_mask("moving-tile")
        local empty_space_collision_layer = collision_mask_util_extended.get_named_collision_mask("empty-space-tile")
        table.insert(path_request_params.collision_mask, spaceship_collision_layer)
        table.insert(path_request_params.collision_mask, empty_space_collision_layer)
    end

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


--===========================================================================--

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

function job:check_items(item_list)
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
                    self.last_robot_positions[bot.unit_number] = current_position
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
        self.worker = job_proc.get_worker(self.surface_index)
        if self.worker and self.worker.valid then
            -- lock constructron
            ctron.set_constructron_status(self.worker, 'busy', true)
            -- change selected constructron colour
            ctron.paint_constructron(self.worker, self.job_type)
            self.state = "new"
        else
            return false
        end
    end
end

function job:validate_station()
    if self.station and self.station.valid and self.station.logistic_network then
        return true
    elseif self.worker and self.worker.valid then
        local new_station = ctron.get_closest_service_station(self.worker)
        if new_station and new_station.valid and new_station.logistic_network then
            self.station = new_station
            return true
        else
            local surface_stations = ctron.get_service_stations(self.surface_index)
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
    local worker = self.worker
    local last_distance = self.last_distance
    local current_distance = chunk_util.distance_between(worker.position, worker.autopilot_destination) or 0
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

-- function to update a combinator of a station
---@param station LuaEntity
---@param item_name string
---@param item_count integer
job_proc.update_combinator = function(station, item_name, item_count)
    if not station or not station.valid or not item_name or not item_count then return end

    -- update master list
    local signals = global.station_combinators[station.unit_number]["signals"]

    signals[item_name] = ((signals[item_name] or 0) + item_count)

    if signals[item_name] < 0 then
        signals[item_name] = 0
    end

    -- update combinator signals
    local index = 2
    local parameters = {}
    local surface_index = station.surface.index
    parameters[1] = {index = 1, signal = {type = "virtual", name = "signal-C"}, count = global.constructrons_count[surface_index]}
    parameters[2] = {index = 2, signal = {type = "virtual", name = "signal-A"}, count = global.available_ctron_count[surface_index]}
    for item, count in pairs(signals) do
        if index > 98 then break end -- the combinator only has 100 slots
        index = index + 1
        parameters[index] = {
            index = index,
            signal = {
                type = "item",
                name = item
            },
            count = count
        }
    end

    global.station_combinators[station.unit_number]["signals"] = signals
    global.station_combinators[station.unit_number].entity.get_control_behavior().parameters = parameters
end

-- method to remove all requests of a job from a combinator
function job:remove_combinator_requests(items)
    for item, value in pairs(items) do
        job_proc.update_combinator(self.station, item, (value.count * -1))
    end
end

-------------------------------------------------------------------------------
--  Job processing
-------------------------------------------------------------------------------

job_proc.process_job_queue = function()
    -- job creation
    if global.queue_proc_trigger then  -- there is something to do start processing
        job_proc.make_jobs()
    end
    -- job operation
    if global.job_proc_trigger then
        for job_index, job in pairs(global.jobs) do
            if not (job.state == "deffered") then
                if not job:validate_worker() or not job:validate_station() then
                    if not game.surfaces[job.surface_index] then
                        global.jobs[job_index] = nil
                    end
                    goto continue
                end
            end
            local worker
            worker = job.worker
            if job.state == "new" then
                if next(job.chunks) then
                    -- calculate chunk build positions
                    for _, chunk in pairs(job.chunks) do
                        debug_lib.draw_rectangle(chunk.minimum, chunk.maximum, job.surface_index, "yellow", false, 3600)
                        local positions = chunk_util.calculate_construct_positions({chunk.minimum, chunk.maximum}, worker.logistic_cell.construction_radius * 0.95) -- 5% tolerance
                        for _, position in ipairs(positions) do
                            debug_lib.VisualDebugCircle(position, job.surface_index, "yellow", 0.5, 3600)
                            table.insert(job.task_positions, position)
                        end
                        if chunk.required_items["landfill"] then
                            job.landfill_job = true
                        end
                    end
                    -- set default ammo request
                    if global.ammo_count[job.surface_index] > 0 and (worker.name ~= "constructron-rocket-powered") then
                        job.required_items[global.ammo_name[job.surface_index]] = global.ammo_count[job.surface_index]
                    end
                    -- enable_logistics_while_moving for destroy jobs
                    if job.job_type == "destroy" then
                        worker.enable_logistics_while_moving = true
                        job.required_items[global.repair_tool_name[job.surface_index]] = global.desired_robot_count[job.surface_index] * 4
                    end
                    -- state change
                    job.state = "starting"
                else
                    -- unlock constructron
                    ctron.set_constructron_status(worker, 'busy', false)
                    -- change constructron colour
                    ctron.paint_constructron(worker, 'idle')
                    -- remove job from list
                    global.jobs[job_index] = nil
                    game.print("Constructron-Continued: No chunk was included in job, job removed. Please report this to mod author.")
                end










            elseif job.state == "starting" then
                -- request path to station
                local distance = chunk_util.distance_between(worker.position, job.station.position)
                if distance > 10 then -- 10 is the logistic radius of a station
                    debug_lib.VisualDebugText("Moving to position", worker, -1, 1)
                    if not worker.autopilot_destination and (job.path_request_id == nil) then
                        job:move_to_position(job.station.position)
                    else
                        if not job:mobility_check() then
                            debug_lib.VisualDebugText("Stuck!", worker, -2, 1)
                            worker.autopilot_destination = nil
                            job.last_distance = nil
                        end
                    end
                else -- constructron is in range of a station
                    debug_lib.VisualDebugText("Awaiting logistics", worker, -1, 1)
                    local logistic_condition = true
                    if not global.constructron_requests[worker.unit_number].station then
                        global.constructron_requests[worker.unit_number].station = job.station
                    end
                    -- request items / check inventory
                    local inventory = worker.get_inventory(defines.inventory.spider_trunk) -- spider inventory
                    local inventory_items = inventory.get_contents() -- spider inventory contents
                    local ammo_slots = worker.get_inventory(defines.inventory.spider_ammo) -- ammo inventory
                    local ammunition = ammo_slots.get_contents() -- ammo inventory contents
                    local current_requests = {} -- current reqests that a spider is making
                    if inventory and ammunition then
                        local supply_items = job_proc.combine_tables({inventory_items, ammunition})
                        if not (job.sub_state == "items_requested") then
                            local item_request_list = table.deepcopy(job.required_items)
                            -- check inventory for unwanted items
                            for item, _ in pairs(supply_items) do
                                if not job.required_items[item] then
                                    item_request_list[item] = 0
                                end
                            end
                            -- check ammo slots for unwanted items
                            for item, _ in pairs(ammunition) do
                                if item ~= global.ammo_name[job.surface_index] then
                                    item_request_list[item] = 0
                                end
                            end
                            item_request_list = job:check_items(item_request_list)
                            job:request_items(item_request_list)
                            logistic_condition = false
                            job.sub_state = "items_requested"
                            job.request_tick = game.tick
                            goto continue
                        else
                            --populate current requests
                            for i = 1, worker.request_slot_count do ---@cast i uint
                                local request = worker.get_vehicle_logistic_slot(i)
                                if request and request.name then
                                    current_requests[request.name] = {
                                        count = request.max,
                                        slot = i
                                    }
                                end
                            end
                            -- check if requested items have been delivered
                            for request_name, value in pairs(current_requests) do
                                local supply_check = (((supply_items[request_name] or 0) >= value.count) and ((supply_items[request_name] or 0) <= value.count))
                                if not supply_check then
                                    logistic_condition = false
                                else
                                    worker.clear_vehicle_logistic_slot(value.slot)
                                end
                            end
                        end
                    end
                    -- station roaming
                    local ticks = (game.tick - job.request_tick)
                    if (ticks > 900) and not logistic_condition then
                        if (global.stations_count[(job.surface_index)] > 1) then
                            -- check if current station network can provide
                            local logistic_network = job.station.logistic_network
                            for request_name, value in pairs(current_requests) do
                                if logistic_network and logistic_network.can_satisfy_request(request_name, value.count, true) then
                                    if not (logistic_network.all_logistic_robots <= 0) then
                                        goto continue
                                    else
                                        debug_lib.VisualDebugText("No logistic robots in network", worker, -0.5, 3)
                                        goto continue
                                    end
                                end
                            end
                            -- check if other station networks can provide
                            local surface_stations = ctron.get_service_stations(job.surface_index)
                            for _, station in pairs(surface_stations) do
                                local station_logistic_network = station.logistic_network
                                if station_logistic_network then
                                    for request_name, value in pairs(current_requests) do
                                        if station_logistic_network.can_satisfy_request(request_name, value.count, true) then
                                            debug_lib.VisualDebugText("Trying a different station", worker, 0, 5)
                                            job:remove_combinator_requests(current_requests) -- remove all requests from circuit
                                            global.constructron_requests[worker.unit_number].station = station -- update request station
                                            job.sub_state = nil
                                            job.station = station
                                            goto continue
                                        end
                                    end
                                end
                            end
                        end
                    end
                    -- check trash has been taken
                    local trash_inventory = worker.get_inventory(defines.inventory.spider_trash)
                    local trash_items
                    if trash_inventory then
                        trash_items = trash_inventory.get_contents()
                        if next(trash_items) then
                            logistic_condition = false
                        end
                    end
                    if logistic_condition then -- requested items have been delivered and trash items have been taken
                        -- divide ammo evenly between slots
                        if ammunition and ammunition[global.ammo_name[job.surface_index]] then
                            local ammo_count = ammunition[global.ammo_name[job.surface_index]]
                            local ammo_per_slot = math.ceil(ammo_count / #ammo_slots)
                            for i = 1, #ammo_slots do
                                local slot = ammo_slots[i]
                                if slot then
                                    slot.clear()
                                    slot.set_stack({name = global.ammo_name[job.surface_index], count = ammo_per_slot})
                                end
                            end
                        end
                        -- clear logistic request and proceed with job
                        for i = 1, worker.request_slot_count do --[[@cast i uint]]
                            worker.clear_vehicle_logistic_slot(i)
                        end
                        -- update job state
                        job.sub_state = nil
                        job.request_tick = nil
                        job.state = "in_progress"
                    end
                end







            elseif job.state == "in_progress" then
                local _, task_position = next(job.task_positions)
                if not next(job.task_positions) then
                    job:check_chunks()
                    job.state = "finishing"
                    goto continue
                end

                local logistic_cell
                local logistic_network

                -- check that the worker has roboports
                if worker.logistic_cell then
                    logistic_cell = worker.logistic_cell
                    logistic_network = logistic_cell.logistic_network
                else
                    -- IDEA: Factorio v2 request equipment
                    debug_lib.VisualDebugText("Missing roboports in equipment grid!", worker, -0.5, 5)
                    goto continue
                end
                -- check that the worker has contruction robots
                if (logistic_network.all_construction_robots < 1) then
                    debug_lib.VisualDebugText("Missing robots! returning to station.", worker, -0.5, 5)
                    job.state = "starting"
                    goto continue
                end

                -- check health
                local health = worker.get_health_ratio()
                if health < 0.6 then
                    debug_lib.VisualDebugText("Fleeing!", worker, -0.5, 1)
                    -- set the station as an iterim retreat target but request a path to take over
                    worker.autopilot_destination = job.station.position
                    job:move_to_position(job.station.position)
                    job.state = "finishing"
                    goto continue
                end

                -- Am I in the correct position?
                local distance_from_pos = chunk_util.distance_between(worker.position, task_position)
                if distance_from_pos > 3 then
                    debug_lib.VisualDebugText("Moving to position", worker, -1, 1)
                    if not worker.autopilot_destination and job.path_request_id == nil then
                        job:move_to_position(task_position)
                    else
                        if job.landfill_job and not logistic_network.can_satisfy_request("landfill", 1) then -- is this a landfill job and do we have landfill?
                            debug_lib.VisualDebugText("Job wrapup: No landfill", worker, -0.5, 5)
                            worker.autopilot_destination = nil
                            job:check_chunks()
                            job.state = "finishing"
                            goto continue
                        end
                        if not job:mobility_check() then
                            debug_lib.VisualDebugText("Stuck!", worker, -2, 1)
                            worker.autopilot_destination = nil
                            job.last_distance = nil
                        end
                    end
                else
                    --===========================================================================--
                    --  Common logic
                    --===========================================================================--
                    local construction_robots = logistic_network.construction_robots
                    local entities

                    debug_lib.VisualDebugText("Constructing", worker, -1, 1) -- move this

                    if not job.roboports_enabled then -- enable full roboport range (applies to landfil jobs)
                        job:enable_roboports()
                        goto continue
                    end

                    if next(construction_robots) then -- are robots deployed?
                        if not job:check_robot_activity(construction_robots) then -- are robots active?
                            if (logistic_cell.charging_robot_count == 0) then
                                job.last_robot_positions = {}
                                table.remove(job.task_positions, 1)
                            end
                        end
                    else -- robots are not deployed
                        --===========================================================================--
                        --  Deconstruction logic
                        --===========================================================================--
                        if job.job_type == "deconstruction" then
                            entities = worker.surface.find_entities_filtered {
                                position = worker.position,
                                radius = logistic_cell.construction_radius,
                                to_be_deconstructed = true,
                                force = {worker.force, "neutral"}
                            } -- only detects entities in range
                            local can_remove_entity = false
                            for _, entity in pairs(entities) do
                                if not (entity.type == "cliff") or logistic_network.can_satisfy_request("cliff-explosives", 1) then
                                    can_remove_entity = true
                                    break
                                end
                            end
                            if not can_remove_entity then
                                table.remove(job.task_positions, 1)
                            end
                        --===========================================================================--
                        --  Construction logic
                        --===========================================================================--
                        elseif job.job_type == "construction" then
                            -- IDEA: Use LuaSurface.count_entities_filtered() as a precursor?
                            entities = worker.surface.find_entities_filtered {
                                position = worker.position,
                                radius = logistic_cell.construction_radius,
                                name = {"entity-ghost", "tile-ghost", "item-request-proxy"},
                                force = worker.force
                            } -- only detects entities in range
                            local can_build_entity = false
                            for _, entity in pairs(entities) do
                                local item
                                if entity.name == "entity-ghost" or entity.name == "tile-ghost" then -- is the entity a ghost?
                                    item = entity.ghost_prototype.items_to_place_this[1]
                                else -- entity is an item_request_proxy
                                    item = {}
                                    for name, count in pairs(entity.item_requests) do
                                        item.name = name
                                        item.count = count
                                    end
                                end
                                if logistic_network.can_satisfy_request(item.name, (item.count or 1)) then -- does inventory have the required item?
                                    can_build_entity = true
                                    break
                                end
                            end
                            if not can_build_entity then
                                table.remove(job.task_positions, 1)
                            end
                        --===========================================================================--
                        --  Upgrade logic
                        --===========================================================================--
                        elseif job.job_type == "upgrade" then
                            entities = worker.surface.find_entities_filtered {
                                position = worker.position,
                                radius = logistic_cell.construction_radius,
                                to_be_upgraded = true,
                                force = worker.force.name
                            } -- only detects entities in range
                            local can_upgrade_entity = false
                            for _, entity in pairs(entities) do
                                local target = entity.get_upgrade_target()
                                if logistic_network.can_satisfy_request(target.items_to_place_this[1].name, 1) then -- does inventory have the required item?
                                    can_upgrade_entity = true
                                end
                            end
                            if not can_upgrade_entity then
                                table.remove(job.task_positions, 1)
                            end
                        --===========================================================================--
                        --  Repair logic
                        --===========================================================================--
                        elseif job.job_type == "repair" then
                            if not job.repair_started then
                                job.repair_started = true -- flag to ensure that at least 1 second passes before changing job state
                                goto continue
                            end
                            table.remove(job.task_positions, 1)
                        --===========================================================================--
                        --  Destroy logic
                        --===========================================================================--
                        elseif job.job_type == "destroy" then
                            -- check ammo
                            local ammo_slots = worker.get_inventory(defines.inventory.spider_ammo)
                            local ammunition = ammo_slots.get_contents()
                            -- retreat when at 25% of ammo
                            local ammo_name = global.ammo_name[job.surface_index]
                            if ammunition and ammunition[ammo_name] and ammunition[ammo_name] < (math.ceil(global.ammo_count[job.surface_index] * 25 / 100)) then
                                job.state = "finishing"
                                goto continue
                            end
                            entities = worker.surface.find_entities_filtered {
                                position = worker.position,
                                radius = 32,
                                force = {"enemy"},
                                is_military_target = true
                            } -- only detects entities in range
                            if not next(entities) then
                                table.remove(job.task_positions, 1)
                            end
                        end
                    end
                end











            elseif job.state == "finishing" then
                local distance = chunk_util.distance_between(worker.position, job.station.position)
                worker.enable_logistics_while_moving = false
                if distance > 10 then -- 10 is the logistic radius of a station
                    debug_lib.VisualDebugText("Moving to position", worker, -1, 1)
                    if not worker.autopilot_destination and (job.path_request_id == nil) then
                        job:move_to_position(job.station.position)
                    else
                        if not job:mobility_check() then
                            debug_lib.VisualDebugText("Stuck!", worker, -2, 1)
                            worker.autopilot_destination = nil
                            job.last_distance = nil
                        end
                    end
                else
                    if not job.roboports_enabled then -- enable full roboport range (due to landfil jobs disabling them)
                        job:enable_roboports()
                    end
                    -- clear items
                    local inventory = worker.get_inventory(defines.inventory.spider_trunk)
                    local inventory_items = inventory.get_contents()
                    if inventory then
                        if not (job.sub_state == "items_requested") then
                            local item_request = {}
                            for item, _ in pairs(inventory_items) do
                                item_request[item] = 0
                            end
                            job:request_items(item_request)
                            job.sub_state = "items_requested"
                            job.request_tick = game.tick
                            goto continue
                        else
                            -- check trash has been taken
                            local trash_inventory = worker.get_inventory(defines.inventory.spider_trash)
                            local trash_items
                            if trash_inventory then
                                trash_items = trash_inventory.get_contents()
                                if next(trash_items) then
                                    local logistic_network = job.station.logistic_network
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
                                                goto continue
                                            end
                                        end
                                    end
                                    -- check if other station networks can store items
                                    local surface_stations = ctron.get_service_stations(job.surface_index)
                                    for _, station in pairs(surface_stations) do
                                        if station.logistic_network then
                                            for item_name, item_count in pairs(trash_items) do
                                                local can_drop = station.logistic_network.select_drop_point({stack = {name = item_name, count = item_count}})
                                                if can_drop then
                                                    debug_lib.VisualDebugText("Trying a different station", worker, 0, 5)
                                                    job.station = station
                                                    goto continue
                                                end
                                            end
                                        end
                                    end
                                    goto continue
                                else
                                    job.sub_state = nil
                                    job.request_tick = nil
                                    for i = 1, worker.request_slot_count do ---@cast i uint
                                        local request = worker.get_vehicle_logistic_slot(i)
                                        if request then
                                            worker.clear_vehicle_logistic_slot(i)
                                        end
                                    end
                                end
                            end
                            -- clear combinator request cache
                            global.constructron_requests[worker.unit_number].requests = {}
                        end
                    end
                    if (global.constructrons_count[job.surface_index] > 10) then
                        local stepdistance = 5 + math.random(5)
                        local alpha = math.random(360)
                        local offset = {x = (math.cos(alpha) * stepdistance), y = (math.sin(alpha) * stepdistance)}
                        local new_position = {x = (worker.position.x + offset.x), y = (worker.position.y + offset.y)}
                        worker.autopilot_destination = new_position
                    end
                    -- unlock constructron
                    ctron.set_constructron_status(worker, 'busy', false)
                    global.available_ctron_count[job.surface_index] = global.available_ctron_count[job.surface_index] + 1
                    -- update combinator with dummy entity to reconcile available_ctron_count
                    job_proc.update_combinator(job.station, "constructron_pathing_proxy_1", 0)
                    -- change selected constructron colour
                    ctron.paint_constructron(worker, 'idle')
                    -- remove job from list
                    global.jobs[job_index] = nil
                    debug_lib.VisualDebugText("Job complete!", worker, -1, 1)
                end



            elseif job.state == "robot_collection" then
                local logistic_network = worker.logistic_cell.logistic_network
                if next(logistic_network) and logistic_network.construction_robots[1] then
                    local distance = chunk_util.distance_between(worker.position, logistic_network.construction_robots[1].position)
                    if not worker.autopilot_destination and job.path_request_id == nil then
                        if distance > 3 then
                            -- Get the positions of the Spidertron and the robot
                            local spidertron_pos = worker.position
                            local robot_pos = logistic_network.construction_robots[1].position
                            -- Get the speed of the Spidertron and the robot
                            local spidertron_speed = ctron.calculate_spidertron_speed(worker)
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
                            job:move_to_position(meeting_point)
                        else
                            -- check that robots are charging and if not, change job state to finishing
                            local logistic_cell = worker.logistic_cell
                            if logistic_cell and (logistic_cell.charging_robot_count == 0) then
                                job.state = "finishing"
                            end
                        end
                    end
                else
                    job.state = "finishing"
                end


            elseif job.state == "deferred" then
                if job.deffered_tick < game.tick then
                    --TODO: deffered logic [currently unused]
                end
            end
            ::continue::
        end
        if not next(global.jobs) then
            global.job_proc_trigger = false
        end
    end
end








-------------------------------------------------------------------------------
--  Utility
-------------------------------------------------------------------------------

job_proc.make_jobs = function()
    local trigger_skip = false
    local job_types = {
        "deconstruction",
        "construction",
        "upgrade",
        "repair",
        "destroy"
    }

    -- for each surface
    for surface_index, _ in pairs(global.managed_surfaces) do
        local exitloop
        -- for each queue
        for _, job_type in pairs(job_types) do
            while next(global[job_type .. '_queue'][surface_index]) and (exitloop == nil) do
                if global.horde_mode then
                    for _, _ in pairs(global[job_type .. '_queue'][surface_index]) do
                        local worker = job_proc.get_worker(surface_index)
                        if not (worker and worker.valid) then
                            trigger_skip = true
                            exitloop = true
                            break
                        end
                        global.job_index = global.job_index + 1
                        global.jobs[global.job_index] = job_proc.new(global.job_index, surface_index, job_type, worker)
                        -- add robots to job
                        global.jobs[global.job_index].required_items = {[global.desired_robot_name[surface_index]] = global.desired_robot_count[surface_index]}
                        global.jobs[global.job_index]:get_chunk()
                        global.job_proc_trigger = true -- start job operations
                    end
                else
                    local worker = job_proc.get_worker(surface_index)
                    if not (worker and worker.valid) then
                        trigger_skip = true
                        break
                    end
                    global.job_index = global.job_index + 1
                    global.jobs[global.job_index] = job_proc.new(global.job_index, surface_index, job_type, worker)
                    -- add robots to job
                    global.jobs[global.job_index].required_items = {[global.desired_robot_name[surface_index]] = global.desired_robot_count[surface_index]}
                    global.jobs[global.job_index]:get_chunk()
                    global.jobs[global.job_index]:find_chunks_in_proximity()
                    global.job_proc_trigger = true -- start job operations
                end
            end
        end
    end
    if not trigger_skip then
        global.queue_proc_trigger = false -- stop queue processing
    end
end

script.on_event(defines.events.on_entity_logistic_slot_changed, function(event)
    local entity = event.entity
    local entity_name = entity.name
    if entity_name ~= "constructron" or entity_name ~= "constructron-rocket-powered" then
        return
    end

    local slot = event.slot_index
    local logistic_request = entity.get_vehicle_logistic_slot(slot)
    local unit_number = entity.unit_number

    if logistic_request.name then
        global.constructron_requests[unit_number]["requests"][slot] = {
            item_name = logistic_request.name,
            item_count = logistic_request.min
        }
        job_proc.update_combinator(global.constructron_requests[unit_number].station, logistic_request.name, logistic_request.min)
    else
        local item_request = global.constructron_requests[unit_number]["requests"][slot]
        if not item_request then return end
        job_proc.update_combinator(global.constructron_requests[unit_number].station, item_request.item_name, (item_request.item_count * -1))
        global.constructron_requests[unit_number]["requests"][slot] = nil
    end
end)

---@param surface_index uint
---@return LuaEntity?
job_proc.get_worker = function(surface_index)
    for _, constructron in pairs(global.constructrons) do
        if constructron and constructron.valid and (constructron.surface.index == surface_index) and not ctron.get_constructron_status(constructron, 'busy') then
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
                local logistic_network = logistic_cell.logistic_network
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
                    ctron.set_constructron_status(constructron, 'busy', true)
                    global.job_index = global.job_index + 1
                    global.jobs[global.job_index] = job_proc.new(global.job_index, surface_index, "utility", constructron)
                    global.jobs[global.job_index].state = "robot_collection"
                    global.job_proc_trigger = true
                end
            end
        end
    end
end

---@param required_items ItemCounts
---@return integer
job_proc.calculate_required_inventory_slot_count = function(required_items)
    local slots = 0
    local stack_size

    for name, count in pairs(required_items) do
        if not global.stack_cache[name] then
            stack_size = game.item_prototypes[name].stack_size
            global.stack_cache[name] = stack_size
        else
            stack_size = global.stack_cache[name]
        end
        slots = slots + math.ceil(count / stack_size)
    end
    return slots
end

job_proc.combine_tables = function(tables)
    local combined = {}
    for _, t in pairs(tables) do
        for k, v in pairs(t) do
            combined[k] = (combined[k] or 0) + v
        end
    end
    return combined
end

return job_proc
