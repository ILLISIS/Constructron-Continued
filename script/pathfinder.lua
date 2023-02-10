local cust_lib = require("script/custom_lib")
local collision_mask_util_extended = require("script/collision-mask-util-control")
local debug_lib = require("script/debug_lib")

-------------------------------------------------------------------------------
--  Init
-------------------------------------------------------------------------------

local clean_linear_path_enabled = true
local clean_path_steps_enabled = false
local clean_path_steps_distance = 5
local non_colliding_position_accuracy = 0.5

local pathfinder = {}

pathfinder.init_globals = function()
    global.pathfinder_requests = global.pathfinder_requests or {}
    --So, when path cache is enabled, negative path cache is also enabled.
    --The problem is, when a single unit inside a nest can't get to the silo,
    --He tells all other biters nearby that they also can't get to the silo.
    --Which causes whole groups of them just to chillout and idle...
    --This applies to all paths as the pathfinder is generic - Klonan
    global.pathfinder_queue = global.pathfinder_queue or {}
    global.path_queue_trigger = global.path_queue_trigger or true
    game.map_settings.path_finder.use_path_cache = false
end

script.on_event(defines.events.on_script_path_request_finished, (function(event)
    pathfinder.on_script_path_request_finished(event)
end))

-------------------------------------------------------------------------------
--  Request path
-------------------------------------------------------------------------------

---@param unit LuaEntity[]
---@param destination MapPosition
---@param job Job?
function pathfinder.init_path_request(unit, destination, job)
    ---@type LuaSurface.request_path_param
    local request_params = {unit = unit, goal = destination, job = job}
    if request_params.unit.name == "constructron-rocket-powered" then
        if request_params.job then
            request_params.job.path_active = true
        end
        pathfinder.set_autopilot(unit, {{position = destination}})
    else
        if (job ~= nil) and job.landfill_job then
            local spot = request_params.unit.surface.find_non_colliding_position("constructron_pathing_proxy_" .. "1", destination, 1, 4, false)
            if spot then -- check position is reachable
                debug_lib.VisualDebugCircle(spot, request_params.unit.surface, "yellow", 0.75, 1200)
                pathfinder.request_path(request_params)
            else -- position is unreachable so find the mainland
                local mainland = request_params.unit.surface.find_non_colliding_position("constructron_pathing_proxy_" .. "64", destination, 800, 4, false)
                if mainland then
                    -- I would like to find a more accurate / closer shore position
                    -- local params = {
                    --     {size = 12, radius = 32},
                    --     {size = 5, radius = 16},
                    --     {size = 5, radius = 8},
                    --     {size = 1, radius = 12},
                    --     {size = 1, radius = 5}
                    --     }
                    -- for _, param in pairs(params) do
                    --     new_position = surface.find_non_colliding_position("constructron_pathing_proxy_" .. param.size, position, param.radius, non_colliding_position_accuracy, false)
                    --     if new_position then
                    --         bb = param
                    --     end
                    -- end
                    request_params.initial_target = destination
                    request_params.landfill_job = job.landfill_job
                    request_params.goal = mainland
                    pathfinder.request_path(request_params)
                end
            end
        else
            pathfinder.request_path(request_params)
        end
    end
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
    pathfinder.set_autopilot(request_params.unit, {}) -- stop walking if walking
    local bounding_box = request_params.bounding_box or {{-5, -5}, {5, 5}}
    local path_resolution_modifier = request_params.path_resolution_modifier or -2
    local landfill_job = request_params.landfill_job or false
    if landfill_job then
        bounding_box = {{-0.015, -0.015}, {0.015, 0.015}}
        path_resolution_modifier = 0
    end
    local request = { -- template
        job = request_params.job or nil, -- The job that initiated this request. Used to update the job. Not used by the factorio-pathfinder
        unit = request_params.unit, -- Unit that this path request is for. Used to add waypoints to the unit and surface id. not used by the factorio-pathfinder
        surface = request_params.unit.surface, -- The surface this path request is for. Not used by the factorio-pathfinder
        landfill_job = landfill_job, -- Identifies if this path request is for a landfill job. Not used by the factorio-pathfinder
        bounding_box = bounding_box,
        collision_mask = pathing_collision_mask,
        start = request_params.start or request_params.unit.position,
        goal = request_params.goal,
        force = request_params.unit.force,
        radius = 1, -- the radius parameter only works in situations where it is useless. It does not help when a position is not reachable. Instead, we use find_non_colliding_position.
        path_resolution_modifier = path_resolution_modifier,
        pathfinding_flags = {
            cache = true,
            low_priority = false
        },
        attempt = request_params.attempt or 1, -- The count of path attemps. Not used by the factorio-pathfinder
        try_again_later = request_params.try_again_later or 0 -- The count of path requests that have been put back because the path finder is busy. Not used by the factorio-pathfinder
    }
    if request_params.initial_target then -- landfill goal
        request.initial_target = request_params.initial_target
    end
    request.initial_target = request.initial_target or request_params.goal -- The initial goal of the job request. Not used by the factorio-pathfinder
    local request_id = request.surface.request_path(request) -- request the path from the game
    global.pathfinder_requests[request_id] = request
    if request_params.job then -- if there is a job update the job with the path request id so we can track it
        request_params.job.request_pathid = request_id
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
            table.insert(global.pathfinder_queue, request)
            global.path_queue_trigger = true
        elseif not path then
            request.attempt = request.attempt + 1
            if request.attempt < 5 then
                if request.attempt == 2 then -- 2. Re-Request ensuring the start of the path is not colliding
                    debug_lib.VisualDebugCircle(request.start, request.surface, "green", 0.75, 600)
                    request.start = pathfinder.find_non_colliding_position(request.surface, request.start) or request.start
                    debug_lib.VisualDebugCircle(request.start, request.surface, "purple", 0.75, 600)
                elseif request.attempt == 3 then -- 3. Re-Request ensuring the goal of the path is not colliding
                    debug_lib.VisualDebugCircle(request.goal, request.surface, "green", 0.75, 600)
                    request.goal = pathfinder.find_non_colliding_position(request.surface, request.goal, request.job) or request.goal
                    debug_lib.VisualDebugCircle(request.goal, request.surface, "purple", 0.75, 600)
                elseif request.attempt == 4 then -- 4. Re-Request with higher pathing precision
                    request.bounding_box = {{-0.015, -0.015}, {0.015, 0.015}}
                    request.path_resolution_modifier = 0
                end
                request.request_tick = game.tick
                pathfinder.request_path(request) -- try again
            else -- 5. f*ck it... just try to walk there in a straight line
                pathfinder.set_autopilot(request.unit, {{position = {x = request.initial_target.x, y = request.initial_target.y}}})
            end
        else
            if clean_linear_path_enabled then
                path = pathfinder.clean_linear_path(path)
            end
            if clean_path_steps_enabled then
                path = pathfinder.clean_path_steps(path, clean_path_steps_distance)
            end
            if request.landfill_job then
                table.insert(path, {position = {x = request.initial_target.x, y = request.initial_target.y}}) -- add the desired destination after the walkable path
            end
            -- table.insert(path, {position = {x = request.initial_target.x, y = request.initial_target.y}}) -- add the desired destination after the walkable path
            -- we currently cannot do this as the job condition will not match. Additionally, if we account for that it could result in a waypoint loop with FNCP.
            -- possibly the poisition_done condition could be changed to check for proximity to both initial and updated destination.
            pathfinder.set_autopilot(request.unit, path)
        end
        if request.job and (path or (request.attempt > 4)) and next(request.job.constructron.autopilot_destination) then
            request.job.path_active = true
        end
    end
    global.pathfinder_requests[event.id] = nil
end

-------------------------------------------------------------------------------
--  Utility
-------------------------------------------------------------------------------

script.on_nth_tick(10, function() -- pathfinder is busy requeue function
    if global.path_queue_trigger then
        if next(global.pathfinder_queue) then
            if global.pathfinder_queue[1].unit and global.pathfinder_queue[1].unit.valid then
                pathfinder.request_path(global.pathfinder_queue[1])
            end
            table.remove(global.pathfinder_queue, 1)
        else
            global.path_queue_trigger = false
        end
    end
end)

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

---@param surface LuaSurface
---@param position MapPosition
---@param job Job?
---@return MapPosition?
function pathfinder.find_non_colliding_position(surface, position, job) -- find a position to stand / walk to
    local new_position
    local params = {
        {size = 12, radius = 64},
        {size = 5, radius = 16},
        {size = 5, radius = 8},
        {size = 1, radius = 12},
        {size = 1, radius = 5}
        }
    for _, param in pairs(params) do
        new_position = surface.find_non_colliding_position("constructron_pathing_proxy_" .. param.size, position, param.radius, non_colliding_position_accuracy, false)
    end
    if new_position then
        if job then -- update the job for condition check
            job.leave_args[1] = new_position
        end
        return new_position -- return for the new request
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
