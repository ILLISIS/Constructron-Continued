local cust_lib = require("script/custom_lib")
local collision_mask_util_extended = require("script/collision-mask-util-control")
local debug_lib = require("script/debug_lib")
local color_lib = require("script/color_lib")

-------------------------------------------------------------------------------
--  Init
-------------------------------------------------------------------------------

local clean_linear_path_enabled = false
local clean_path_steps_enabled = false
local clean_path_steps_distance = 5
local non_colliding_position_accuracy = 0.5

local pathfinder = {}

pathfinder.init_globals = function()
    global.pathfinder_requests = global.pathfinder_requests or {}
end

-------------------------------------------------------------------------------
--  Request path
-------------------------------------------------------------------------------

---@param unit LuaEntity[]
---@param destination MapPosition
---@return MapPosition?
function pathfinder.init_path_request(unit, destination)
    ---@type LuaSurface.request_path_param
    local request_params = {unit = unit, goal = destination}

    if request_params.unit.name == "constructron-rocket-powered" then
        pathfinder.set_autopilot(unit, {{position = destination}})
    else
        global.path_retrys = global.path_retrys or {}
        pathfinder.request_path(request_params)
    end
    return destination
end

---@param request_params LuaSurface.request_path_param
function pathfinder.request_path(request_params)
    local pathing_collision_mask = {"water-tile", "consider-tile-transitions", "colliding-with-tiles-only", "not-colliding-with-itself"}

    if game.active_mods["space-exploration"] then
        local spaceship_collision_layer = collision_mask_util_extended.get_named_collision_mask("moving-tile")
        local empty_space_collision_layer = collision_mask_util_extended.get_named_collision_mask("empty-space-tile")
        table.insert(pathing_collision_mask, spaceship_collision_layer)
        table.insert(pathing_collision_mask, empty_space_collision_layer)
    end
    request_params = request_params or {}

    if request_params.unit and request_params.unit.valid then
        pathfinder.set_autopilot(request_params.unit, {}) -- stop walking if walking
        local request = { -- template
            unit = request_params.unit, -- not used by the factorio-pathfinder
            surface = request_params.unit.surface, -- not used by the factorio-pathfinder
            bounding_box = request_params.bounding_box or {{-5, -5}, {5, 5}}, -- 1st Request: use huge bounding box to avoid pathing near sketchy areas
            collision_mask = pathing_collision_mask,
            start = request_params.unit.position,
            goal = request_params.goal,
            force = request_params.unit.force,
            radius = 1,
            path_resolution_modifier = 0,
            pathfinding_flags = {
                cache = false,
                low_priority = true
            },
            attempt = request_params.attempt or 1, -- not used by the factorio-pathfinder
            try_again_later = 0 -- not used by the factorio-pathfinder
        }

        -- cust_lib.merge(request, request_params) -- merge template with the request_params
        request.initial_target = request.initial_target or request.goal -- not used by the factorio-pathfinder
        request.request_tick = game.tick -- not used by the factorio-pathfinder

        local new_req = table.deepcopy(request)
        local request_id = request.surface.request_path(new_req) -- request the path from the game
        global.pathfinder_requests[request_id] = request
    end
end

-------------------------------------------------------------------------------
--  Path request finished
-------------------------------------------------------------------------------

---@param event EventData.on_script_path_request_finished
function pathfinder.on_script_path_request_finished(event)
    local request = global.pathfinder_requests[event.id]

    if request and request.unit and request.unit.valid then
        local path = event.path

        if event.try_again_later then -- try_again_later is a return of the event handler
            if request.try_again_later < 5 then
                request.request_tick = game.tick
                request.try_again_later = request.try_again_later + 1
                pathfinder.request_path(request)
            end
        elseif not path then
            request.retry = true
            global.path_retrys[#global.path_retrys] = table.deepcopy(request)
        else
            if clean_linear_path_enabled then
                path = pathfinder.clean_linear_path(path)
            end
            if clean_path_steps_enabled then
                path = pathfinder.clean_path_steps(path, clean_path_steps_distance)
            end
            table.insert(path, {position = {x = request.initial_target.x, y = request.initial_target.y}})
            if clean_path_steps_enabled then
                path = pathfinder.clean_path_steps(path, 2.5)
            end
            pathfinder.set_autopilot(request.unit, path)
            global.pathfinder_requests[event.id] = nil
        end
    end
end

-------------------------------------------------------------------------------
--  Utility
-------------------------------------------------------------------------------

---@param unit LuaEntity
---@param path PathfinderWaypoint[]
function pathfinder.set_autopilot(unit, path) -- set path
    if unit and unit.valid then
        unit.autopilot_destination = nil
        for i, waypoint in ipairs(path) do
            unit.add_autopilot_destination(waypoint.position)
        end
    end
end

-- this function was incepted because attempting these operations from the handler would not return a path - possible game bug
function pathfinder.retry_paths()
    if global.path_retrys then
        for k, request in pairs(global.path_retrys) do
            if request.retry then
                request.attempt = request.attempt + 1
                if request.attempt < 7 then
                    if request.attempt == 2 then -- 2. Re-Request with normal bounding box
                        request.bounding_box = {{-1, -1}, {1, 1}}
                    elseif request.attempt == 3 then -- 3. Re-Request with increased radius
                        request.radius = 5
                    elseif request.attempt == 4 then -- 4. Re-Request with tiny bounding box
                        request.bounding_box = {{-0.015, -0.015}, {0.015, 0.015}} -- leg collision_box = {{-0.01, -0.01}, {0.01, 0.01}},
                    elseif request.attempt == 5 then -- 5. find_non_colliding_positions and Re-Request
                        request.start = pathfinder.find_non_colliding_position(request.surface, request.start) or request.start
                        request.goal = pathfinder.find_non_colliding_position(request.surface, request.goal) or request.goal
                    elseif request.attempt == 6 then -- 6. Re-Request with even more increased radius again
                        request.path_resolution_modifier = 2
                        request.radius = 10
                    end
                    request.request_tick = game.tick
                    request.retry = nil
                    global.path_retrys[k] = nil
                    local new_request = table.deepcopy(request)
                    pathfinder.request_path(new_request) -- try again
                else -- 7. f*ck it... just try to walk there in a straight line
                    -- debug_lib.VisualDebugText("No path", request.unit, 0, 3)
                    pathfinder.set_autopilot(request.unit, {{position = {x = request.initial_target.x, y = request.initial_target.y}}})
                end
            end
        end
    end
end

---@param surface LuaSurface
---@param position MapPosition
---@return MapPosition?
function pathfinder.find_non_colliding_position(surface, position) -- find a position to stand / walk to
    for _, param in pairs(
        {
            {size = 12, radius = 8},
            {size = 8, radius = 8},
            {size = 6, radius = 8},
            {size = 4, radius = 8},
            {size = 2, radius = 8},
            {size = 1, radius = 32}
        }
    ) do
        local new_position =
            surface.find_non_colliding_position("constructron_pathing_proxy_" .. param.size, position, param.radius, non_colliding_position_accuracy, false)
        if new_position then
            return new_position
        end
    end
end

function pathfinder.check_pathfinder_requests_timeout()
    for key, request in pairs(global.pathfinder_requests) do
        if ((game.tick - request.request_tick) > 60 * 60) then -- one minute
            global.pathfinder_requests[key] = nil
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
