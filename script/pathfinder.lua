local cust_lib = require("script/custom_lib")
local collision_mask_util_extended = require("script/collision-mask-util-control")
local debug_lib = require("script/debug_lib")

-------------------------------------------------------------------------------
--  Init
-------------------------------------------------------------------------------

local clean_linear_path_enabled = true
local clean_path_steps_enabled = true
local clean_path_steps_distance = 5
local non_colliding_position_accuracy = 0.5

pathfinder = {}
pathfinder.__index = pathfinder
script.register_metatable("constructron_pathfinder_table", pathfinder)


function pathfinder.new(start, goal, job)
    start = { x = math.floor(start.x), y = math.floor(start.y) }
    goal = { x = math.floor(goal.x), y = math.floor(goal.y) }
    local instance = setmetatable({}, pathfinder)
    instance.path_index = global.custom_pathfinder_index
    instance.start = start
    instance.goal = goal
    instance.job = job
    instance.surface = job.worker.surface
    job.pathfinding = true
    instance.openSet = {} -- Nodes to be evaluated
    local node = {
        x = start.x,
        y = start.y,
        g = 0,
        h = math.abs(start.x - goal.x) + math.abs(start.y - goal.y) + 1,
    }
    instance.openSet[start.x] = {}
    instance.openSet[start.x][start.y] = node
    instance.closedSet = {} -- Nodes already evaluated
    local lowh_bundle = math.floor(node.h)
    instance.lowh_bundles = {
        [lowh_bundle] = {
            [1] = node
        }
    } -- heuristic cache
    instance.lowesth_value = lowh_bundle
    instance.path_iterations = 0 -- number of path iterations * TilesProcessed
    return instance
end

-------------------------------------------------------------------------------
--  Path request finished
-------------------------------------------------------------------------------

script.on_event(defines.events.on_script_path_request_finished, (function(event)
    on_script_path_request_finished(event)
end))

---@param event EventData.on_script_path_request_finished
function on_script_path_request_finished(event)
    local job = global.pathfinder_requests[event.id]
    if not job or not job.worker or not job.worker.valid then return end
    local path = event.path
    if event.try_again_later then
        -- TODO
        -- update instance
    elseif not path then
        job.path_request_params.path_attempt = job.path_request_params.path_attempt + 1
        if job.path_request_params.path_attempt < 5 then
            local start, goal
            -- check this tomorrow
            debug_lib.VisualDebugCircle(job.path_request_params.start, job.path_request_params.surface, "green", 0.75, 600)
            start = pathfinder.find_non_colliding_position(job, job.path_request_params.start) or job.path_request_params.start
            debug_lib.VisualDebugCircle(job.path_request_params.start, job.path_request_params.surface, "purple", 0.75, 600)
            debug_lib.VisualDebugCircle(job.path_request_params.goal, job.path_request_params.surface, "green", 0.75, 600)
            goal = pathfinder.find_non_colliding_position(job, job.path_request_params.goal) or job.path_request_params.goal
            debug_lib.VisualDebugCircle(job.path_request_params.goal, job.path_request_params.surface, "purple", 0.75, 600)
            if (goal.x ~= job.path_request_params.goal.x) or (goal.y ~= job.path_request_params.goal.y) then
                job.path_request_params.goal = goal
            elseif (start.x ~= job.path_request_params.start.x) or (start.y ~= job.path_request_params.start.y) then
                job.path_request_params.start = start
            else
                job.path_request_params.bounding_box = {{-0.01, -0.01}, {0.01, 0.01}}
                job.path_request_params.path_resolution_modifier = 0
            end
            job:request_path(job.path_request_params) -- try again
        else
            debug_lib.VisualDebugText("No Path!", job.worker, -0.5, 1)
        end
    else
        if clean_linear_path_enabled then
            path = pathfinder.clean_linear_path(path)
        end
        if clean_path_steps_enabled then
            path = pathfinder.clean_path_steps(path, clean_path_steps_distance)
        end
        -- update instance
        job.path_attempt = nil
        job.path_request_params = nil
        -- request path from game engine
        pathfinder.set_autopilot(job.worker, path)
    end
    if job.path_request_id == event.id then
        job.path_request_id = nil
    end
    global.pathfinder_requests[event.id] = nil
end

-------------------------------------------------------------------------------
--  Custom Pathfinder
-------------------------------------------------------------------------------

-- A* pathfinding function
function pathfinder:findpath()
    local start = self.start
    local goal = self.goal
    local openSet = self.openSet -- nodes to be evaluated
    local closedSet = self.closedSet -- nodes already evaluated
    local TilesProcessed = 0 -- tiles processed per iteration
    local lowesth_value = self.lowesth_value -- lowest heuristic value found
    self.path_iterations = self.path_iterations + 1 -- iteration count

    while next(openSet) and (TilesProcessed < 10) and (self.path_iterations < 200) do
        TilesProcessed = TilesProcessed + 1

        local lowh_bundle = self.lowh_bundles[lowesth_value]
        local bundle_index, current_node = next(lowh_bundle)

        -- remove current_node from openSet and add to closedSet
        openSet[current_node.x][current_node.y] = nil
        if not next(openSet[current_node.x]) then
            openSet[current_node.x] = nil
        end
        closedSet[current_node.x] = closedSet[current_node.x] or {}
        closedSet[current_node.x][current_node.y] = current_node

        -- remove from heuristic cache
        self.lowh_bundles[lowesth_value][bundle_index] = nil
        if not next(self.lowh_bundles[lowesth_value]) then
            self.lowh_bundles[lowesth_value] = nil
            local new_lowesth_value, _ = next(self.lowh_bundles)
            if new_lowesth_value and (new_lowesth_value > 1024) then
                for heuristic, _ in pairs(self.lowh_bundles) do
                    if (heuristic < new_lowesth_value) then
                        new_lowesth_value = heuristic
                    end
                end
            end
            lowesth_value = new_lowesth_value
            self.lowesth_value = new_lowesth_value
        end
        -- debug_lib.VisualDebugText("".. current_node.h .."", {}, 0, 30, "green")

        -- check for path result
        if current_node.h < 5 then
            if current_node.x == goal.x and current_node.y == goal.y then
                local path = {}
                while current_node.parent do
                    table.insert(path, 1, current_node)
                    current_node = current_node.parent
                end
                table.insert(path, 1, start)
                table.insert(path, goal)
                -- because the path is searched for in reverse, it needs to be swapped around
                local tableLength = #path
                local reversed_path = {}
                for i = tableLength, 1, -1 do
                    local waypoint = {
                        position = {
                            x = path[i].x,
                            y = path[i].y
                        }
                    }
                    debug_lib.VisualDebugCircle(waypoint.position, self.surface, "green", 0.75, 1800)
                    table.insert(reversed_path, waypoint)
                end
                if clean_linear_path_enabled then
                    reversed_path = pathfinder.clean_linear_path(reversed_path)
                end
                if clean_path_steps_enabled then
                    reversed_path = pathfinder.clean_path_steps(reversed_path, clean_path_steps_distance)
                end
                self.job.custom_path = reversed_path
                self.job.pathfinding = nil
                global.custom_pathfinder_requests[self.path_index] = nil
                return
            end
        end

        -- get neighboring nodes
        local maxDistance = 1
        -- IDEA: pathfinding backwards seems to make it easier to island hop
        -- IDEA: make maxDistance configurable
        -- IDEA: make maxDistance dynamic - try +15 tiles first, then lower to 1
        for dx = -maxDistance, maxDistance do
            for dy = -maxDistance, maxDistance do
                local neighbor = {
                    x = current_node.x + dx,
                    y = current_node.y + dy,
                    g = current_node.g + 1,
                    h = 0,
                    parent = current_node
                }
                neighbor.h = math.abs(neighbor.x - goal.x) + math.abs(neighbor.y - goal.y) + 1
                -- debug_lib.VisualDebugText("".. neighbor.h .."", neighbor, 0, 30)
                if not closedSet[neighbor.x] or not closedSet[neighbor.x][neighbor.y] then
                    if not openSet[neighbor.x] or not openSet[neighbor.x][neighbor.y] then
                        local collides = self.surface.entity_prototype_collides("constructron_pathing_proxy_1", neighbor, false)
                        if not collides or self:isWalkable(neighbor) then
                            if not collides then
                                -- check if the virtual chunk that this node is in is the mainland
                                local var = self:mainland_finder({x = neighbor.x, y = neighbor.y})
                                if (var ~= nil) and not self.mainland_found then
                                    -- mainland found, set the goal of the path finder to be the middle of this virtual chunk
                                    self.mainland_found = true
                                    self.goal = {y = var.y + 48, x = var.x + 48}
                                end
                            end
                            if openSet[neighbor.x] and openSet[neighbor.x][neighbor.y] then
                                local openNode = openSet[neighbor.x][neighbor.y]
                                if neighbor.g < openNode.g then
                                    openNode.g = neighbor.g
                                    openNode.parent = current_node
                                end
                            else
                                -- add to openSet table
                                openSet[neighbor.x] = openSet[neighbor.x] or {}
                                openSet[neighbor.x][neighbor.y] = neighbor
                                -- add to heuristic table
                                heuristic = math.floor(neighbor.h)
                                if (lowesth_value == nil) or (heuristic < lowesth_value) then
                                    lowesth_value = heuristic
                                    self.lowesth_value = heuristic
                                end
                                if not self.lowh_bundles[heuristic] then self.lowh_bundles[heuristic] = {} end
                                table.insert(self.lowh_bundles[heuristic], neighbor)
                            end
                        else
                            debug_lib.VisualDebugCircle(neighbor, self.surface, "red", 0.5, 300)
                            closedSet[neighbor.x] = closedSet[neighbor.x] or {}
                            closedSet[neighbor.x][neighbor.y] = neighbor
                        end
                    end
                else
                    -- these are already processed blocks/tiles
                    -- debug_lib.VisualDebugCircle(neighbor, self.surface, "charcoal", 0.5, 150)
                end
            end
        end
    end
    if (self.path_iterations > 200) or not next(openSet) then
        -- if this is the first attempt to reach this position that failed, move it to the end of the task position queue
        if not self.job.task_positions[1].reattempt then
            self.job.task_positions[1].reattempt = true
            table.insert(self.job.task_positions, self.job.task_positions[1])
            table.remove(self.job.task_positions, 1)
        else
            -- second failed attempt to reach the position
            table.remove(self.job.task_positions, 1)
        end
        self.job.pathfinding = nil
        global.custom_pathfinder_requests[self.path_index] = nil
        debug_lib.VisualDebugText("No path found!", self.job.worker, -0.5, 10)
    end
    return -- No path found
end

-------------------------------------------------------------------------------
--  Utility
-------------------------------------------------------------------------------

function pathfinder:isWalkable(position)
    -- Check for collision with entities (replace "your_collision_mask" with the appropriate collision mask)
    -- local collision_mask = {"player-layer", "consider-tile-transitions", "colliding-with-tiles-only", "not-colliding-with-itself"}
    -- local collides_with_entities = game.surfaces["your_surface_name"].count_entities_filtered{
    --     area = {{tile.x - 0.5, tile.y - 0.5}, {tile.x + 0.5, tile.y + 0.5}},
    --     collision_mask = collision_mask
    -- }

    -- if collides_with_entities > 0 then
    --     return false
    -- end

    tile = self.surface.get_tile(position.x, position.y)
    tile_ghost = tile.has_tile_ghost()

    local water = {
        ["water"] = true,
        ["deepwater"] = true
    } -- TODO: collision masks

    if water[tile.name] then
        if not tile_ghost then
            return false
        end
    end

    return true
end


-- TODO: fix draw calls into debug mode
-- finds the mainland by looking for an area where a size 96 entity will fit
function pathfinder:mainland_finder(position)
    local surface = self.surface
    local chunk = {
        y = math.floor((position.y) / 96),
        x = math.floor((position.x) / 96)
    }
    if not global.checked_chunks then
        global.checked_chunks = {}
    end
    local key = chunk.y .. ',' .. chunk.x
    if not global.checked_chunks[key] then
        global.checked_chunks[key] = true
        test = surface.find_non_colliding_position_in_box("constructron_pathing_proxy_" .. "96", {{
            y = chunk.y * 96,
            x = chunk.x * 96
        }, {
            y = (chunk.y + 1) * 96,
            x = (chunk.x + 1) * 96
        }}, 128, true)

        rendering.draw_rectangle {
            left_top = {y = chunk.y * 96, x = chunk.x * 96},
            right_bottom = {y = (chunk.y + 1) * 96, x = (chunk.x + 1) * 96},
            filled = false,
            width = 16,
            surface = surface,
            time_to_live = 600,
            color = {
                r = 0,
                g = 0.35,
                b = 0.65,
                a = 1
            }
        }
        local new_goal = {
            y = chunk.y * 96,
            x = chunk.x * 96
        }
        if (test ~= nil) then
            debug_lib.draw_rectangle({
                y = chunk.y * 96,
                x = chunk.x * 96
            }, {
                y = (chunk.y + 1) * 96,
                x = (chunk.x + 1) * 96
            }, surface, "green", true, 300)
            debug_lib.VisualDebugCircle(new_goal, surface, "green", 0.75, 900)
            return new_goal
        else
            debug_lib.draw_rectangle({
                y = chunk.y * 96,
                x = chunk.x * 96
            }, {
                y = (chunk.y + 1) * 96,
                x = (chunk.x + 1) * 96
            }, surface, "red", true, 300)
        end
        rendering.draw_text {
            text = "" .. key .. "",
            target = new_goal,
            filled = true,
            scale = 5,
            -- surface = entity.surface,
            surface = surface,
            time_to_live = (10 * 60) or 60,
            target_offset = {0, (offset or 0)},
            alignment = "center",
            color = {
                r = 255,
                g = 255,
                b = 255,
                a = 255
            }
        }
    end
end

function pathfinder.find_non_colliding_position(job, position) -- find a position to stand / walk to
    local new_position
    local params = {
        {size = 12, radius = 64},
        {size = 5, radius = 16},
        {size = 5, radius = 8},
        {size = 1, radius = 12},
        {size = 1, radius = 5}
        }
    for _, param in pairs(params) do
        new_position = job.worker.surface.find_non_colliding_position("constructron_pathing_proxy_" .. param.size, position, param.radius, non_colliding_position_accuracy, false)
    end
    if new_position then
        if job then -- update the job for condition check
            job.task_positions[1] = new_position
        end
        return new_position -- return for the new request
    end
end

---@param unit LuaEntity
---@param path PathfinderWaypoint[]
function pathfinder.set_autopilot(unit, path) -- set path
    if unit and unit.valid then
        -- unit.autopilot_destination = nil -- removed for 2.0
        for i, waypoint in ipairs(path) do
            unit.add_autopilot_destination(waypoint.position)
        end
    end
end

---@param path PathfinderWaypoint[]
---@return PathfinderWaypoint[]
function pathfinder.clean_linear_path(path) -- removes points on the same line except the start and the end.
    local new_path = {}
    for i, waypoint in ipairs(path) do
        if i >= 2 and i < #path then
            local prev_angle = math.atan2(waypoint.position.y - path[i - 1].position.y, waypoint.position.x - path[i - 1].position.x)
            local next_angle = math.atan2(path[i + 1].position.y - waypoint.position.y, path[i + 1].position.x - waypoint.position.x)
            if math.abs(prev_angle - next_angle) > 0.005 then
                table.insert(new_path, waypoint)
            end
        else
            table.insert(new_path, waypoint)
        end
    end
    return new_path
end

---@param path PathfinderWaypoint[]
---@param min_distance integer
---@return PathfinderWaypoint[]
function pathfinder.clean_path_steps(path, min_distance)
    if #path == 1 then
        return path
    end
    local new_path = {}
    local prev = path[1]
    table.insert(new_path, prev)
    for i, p in pairs(path) do
        local d = cust_lib.distance_between(prev.position, p.position)
        if (d > min_distance) then
            prev = p
            table.insert(new_path, p)
        end
    end
    --fix last point
    local d = cust_lib.distance_between(prev.position, path[#path].position)
    if (d > min_distance) or (#new_path == 1) then
        table.insert(new_path, path[#path])
    else
        new_path[#new_path] = path[#path]
    end
    return new_path
end

return pathfinder
