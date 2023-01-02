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
    game.map_settings.path_finder.use_path_cache = false
end

-------------------------------------------------------------------------------
--  Request path
-------------------------------------------------------------------------------

---@param unit LuaEntity[]
---@param destination MapPosition
---@return MapPosition?
function pathfinder.init_path_request(unit, destination, job)
    ---@type LuaSurface.request_path_param
    local request_params = {unit = unit, goal = destination, job = job}

    if request_params.unit.name == "constructron-rocket-powered" then
        pathfinder.set_autopilot(unit, {{position = destination}})
    else
        if job and job.landfill_job then
            local spot = request_params.unit.surface.find_non_colliding_position("constructron_pathing_proxy_" .. "1", destination, 1, 4, false)
            if spot then -- check position is reachable
                debug_lib.VisualDebugCircle(spot, request_params.unit.surface, "blue", 0.5, 1, 3600)
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
    local request = { -- template
        job = request_params.job or nil, -- not used by the factorio-pathfinder
        unit = request_params.unit, -- not used by the factorio-pathfinder
        surface = request_params.unit.surface, -- not used by the factorio-pathfinder
        landfill_job = request_params.landfill_job or false, -- not used by the factorio-pathfinder
        bounding_box = request_params.bounding_box or {{-5, -5}, {5, 5}}, -- 1st Request: use huge bounding box to avoid pathing near sketchy areas
        collision_mask = pathing_collision_mask,
        start = request_params.start or request_params.unit.position,
        goal = request_params.goal,
        force = request_params.unit.force,
        radius = 1, -- the radius parameter only works in situations where it is useless. It does not help when a position is not reachable. Instead, we use find_non_colliding_position.
        path_resolution_modifier = request_params.path_resolution_modifier or -2, -- 1st Reuest: fast path calculation
        pathfinding_flags = {
            cache = true,
            low_priority = true
        },
        attempt = request_params.attempt or 1, -- not used by the factorio-pathfinder
        try_again_later = 0 -- not used by the factorio-pathfinder
    }

    if request_params.initial_target then -- landfill goal
        request.initial_target = request_params.initial_target
    end
    request.initial_target = request.initial_target or request_params.goal -- not used by the factorio-pathfinder
    request.request_tick = game.tick -- not used by the factorio-pathfinder

    local request_id = request.surface.request_path(request) -- request the path from the game
    global.pathfinder_requests[request_id] = request
end

-------------------------------------------------------------------------------
--  Path request finished
-------------------------------------------------------------------------------

---@param event EventData.on_script_path_request_finished
function pathfinder.on_script_path_request_finished(event)
    local request = global.pathfinder_requests[event.id]

    if request and request.unit and request.unit.valid then
        local job = request.job
        local path = event.path

        if event.try_again_later then -- try_again_later is a return of the event handler
            if request.try_again_later < 5 then
                request.request_tick = game.tick
                request.try_again_later = request.try_again_later + 1
                pathfinder.request_path(request)
            end
        elseif not path then
            request.attempt = request.attempt + 1
            if request.attempt < 7 then
                if request.attempt == 2 then -- 2. Re-Request with normal bounding box
                    request.bounding_box = {{-1, -1}, {1, 1}}
                elseif request.attempt == 3 then -- 3. Re-Request ensuring the start of the path is not colliding
                    debug_lib.VisualDebugCircle(request.start, request.surface, "green", 0.5, 1, 600)
                    request.start = pathfinder.find_non_colliding_position(request.surface, request.start) or request.start
                    debug_lib.VisualDebugCircle(request.start, request.surface, "purple", 0.3, 1, 600)
                elseif request.attempt == 4 then -- 4. Re-Reqest with normal path granularity
                    request.path_resolution_modifier = 0
                elseif request.attempt == 5 then 
                    request.bounding_box = {{-0.015, -0.015}, {0.015, 0.015}} -- leg collision_box = {{-0.01, -0.01}, {0.01, 0.01}},
                elseif request.attempt == 6 then -- 5. Re-Request ensuring the goal of the path is not colliding
                    debug_lib.VisualDebugCircle(request.goal, request.surface, "green", 0.5, 1, 600)
                    request.goal = pathfinder.find_non_colliding_position(request.surface, request.goal, job) or request.goal
                    debug_lib.VisualDebugCircle(request.goal, request.surface, "purple", 0.3, 1, 600)
                end
                request.request_tick = game.tick
                pathfinder.request_path(request) -- try again
            else -- 6. f*ck it... just try to walk there in a straight line
                pathfinder.set_autopilot(request.unit, {{position = {x = request.initial_target.x, y = request.initial_target.y}}})
            end
        else
            -- testing
            if request.attempt == 1 then
                game.print('Attempt 1')
            elseif request.attempt == 2 then -- 2. Re-Request with normal bounding box
                game.print('Attempt 2')
            elseif request.attempt == 3 then -- 3. Re-Request with increased radius (just for this try)
                game.print('Attempt 3')
            elseif request.attempt == 4 then -- 4. Re-Request with tiny bounding box
                game.print('Attempt 4')
            elseif request.attempt == 5 then -- 5. find_non_colliding_positions and Re-Request
                game.print('Attempt 5')
            elseif request.attempt == 6 then -- 6. Re-Request with even more increased radius again
                game.print('Attempt 6')
            end
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
            if clean_path_steps_enabled then
                path = pathfinder.clean_path_steps(path, 2.5)
            end
            if request.job then
                global.job_bundles[request.job.bundle_index][1]["path_active"] = true
            end
            pathfinder.set_autopilot(request.unit, path)
        end
    end
    global.pathfinder_requests[event.id] = nil
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

---@param surface LuaSurface
---@param position MapPosition
---@return MapPosition?
function pathfinder.find_non_colliding_position(surface, position, job) -- find a position to stand / walk to
    local new_position
    local bb
    local params = {
        {size = 12, radius = 64},
        {size = 5, radius = 16},
        {size = 5, radius = 8},
        {size = 1, radius = 12},
        {size = 1, radius = 5}
        }
    for _, param in pairs(params) do
        new_position = surface.find_non_colliding_position("constructron_pathing_proxy_" .. param.size, position, param.radius, non_colliding_position_accuracy, false)
        if new_position then
            bb = param
        end
    end
    if new_position then
        if job and (job.action == "go_to_position") then -- update the job for condition check
            global.job_bundles[job.bundle_index][1]["leave_args"][1] = new_position
        end
        game.print('bounding_box:'.. serpent.block(bb) ..'')
        return new_position -- return for the new request
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