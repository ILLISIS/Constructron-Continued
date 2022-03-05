local debug_lib = require("__Constructron-Continued__.script.debug_lib")
local custom_lib = require("__Constructron-Continued__.script.custom_lib")
local color_lib = require("__Constructron-Continued__.script.color_lib")
local collision_mask_util_extended = require("__Constructron-Continued__.script.collision-mask-util-control")

local me = {}

me.init = function()
    global.pathfinder_requests = global.pathfinder_requests or {}
    for key, request in pairs(global.pathfinder_requests) do
        if ((game.tick - request.request_tick) > 60 * 60) then -- one minute
            global.pathfinder_requests[key] = nil
        end
    end
end

me.clean_linear_path = function(path)
    -- removes points on the same line except the start and the end.
    local new_path = {}
    for i, waypoint in ipairs(path) do
        if i >= 2 and i < #path then
            local prev_angle = math.atan2(waypoint.position.y - path[i - 1].position.y, waypoint.position.x - path[i - 1].position.x)
            local next_angle = math.atan2(path[i + 1].position.y - waypoint.position.y, path[i + 1].position.x - waypoint.position.x)
            if math.abs(prev_angle - next_angle) > 0.01 then
                table.insert(new_path, waypoint)
            end
        else
            table.insert(new_path, waypoint)
        end
    end
    return new_path
end

me.clean_path_steps = function(path)
    if #path == 1 then
        return path
    end
    log("path" .. serpent.block(path))
    local min_distance = 12
    local new_path = {}
    local prev = path[1]
    table.insert(new_path, prev)
    for i, p in pairs(path) do
        local d = custom_lib.distance_between(prev.position, p.position)
        if (d > min_distance) then
            prev = p
            table.insert(new_path, p)
        end
    end
    --fix last point
    local d = custom_lib.distance_between(prev.position, path[#path].position)
    if (d > min_distance) or (#new_path == 1) then
        table.insert(new_path, path[#path])
    else
        new_path[#new_path] = path[#path]
    end
    log("new_path" .. serpent.block(new_path))
    return new_path
end

me.find_new_position = function(position, surface)
    -- to avoid issues with pathing we prefer a unobstructed 6x6 area as pathing start/target
    -- if that is unavaliable, we try to fall back to smaller alternatives and hope for the best
    for _, size in pairs({6, 4, 2, 1}) do
        local new_position = surface.find_non_colliding_position("constructron_pathing_proxy_" .. size, position, 32, 0.1, false)
        if new_position then
            return new_position
        end
        debug_lib.DebugLog("area of size " .. size .. " near " .. serpent.block(position) .. " is not reachable")
    end
end

me.request_path = function(spidertrons, _, destination)
    local spidertron = spidertrons[1]
    local new_start, new_destination
    if spidertron.valid then
        local surface = spidertron.surface

        debug_lib.VisualDebugCircle(spidertron.position, surface, color_lib.color_alpha(color_lib.colors.red, 0.2), "S")
        new_start = me.find_new_position(spidertron.position, surface)
        if new_start then
            debug_lib.VisualDebugCircle(new_start, surface, color_lib.color_alpha(color_lib.colors.green, 0.2), "S+")
        else
            debug_lib.VisualDebugText("pathing start position not reachable", spidertron)
            -- try the initial position and hope for the best
            new_start = spidertron.position
        end

        debug_lib.VisualDebugCircle(destination, surface, color_lib.color_alpha(color_lib.colors.red, 0.2), "T")
        new_destination = me.find_new_position(destination, surface)
        if new_destination then
            debug_lib.VisualDebugCircle(new_destination, surface, color_lib.color_alpha(color_lib.colors.green, 0.2), "T+")
        else
            debug_lib.VisualDebugText("pathing destination position not reachable", spidertron)
            -- try the initial position and hope for the best
            new_destination = destination
        end
        debug_lib.VisualDebugCircle(destination, surface, color_lib.color_alpha(color_lib.colors.red, 0.2))

        local pathing_collision_mask = {"water-tile", "consider-tile-transitions", "colliding-with-tiles-only"}
        if game.active_mods["space-exploration"] then
            local spaceship_collision_layer = collision_mask_util_extended.get_named_collision_mask("moving-tile")
            local empty_space_collision_layer = collision_mask_util_extended.get_named_collision_mask("empty-space-tile")
            table.insert(pathing_collision_mask, spaceship_collision_layer)
            table.insert(pathing_collision_mask, empty_space_collision_layer)
        end
        local bounding_box_size = 0
        local request_id =
            surface.request_path {
            bounding_box = {
                {-bounding_box_size / 2, -bounding_box_size / 2},
                {bounding_box_size / 2, bounding_box_size / 2}
            },
            collision_mask = pathing_collision_mask,
            start = new_start,
            goal = new_destination,
            force = spidertron.force,
            pathfinding_flags = {
                cache = false,
                low_priority = true
            }
        }
        global.pathfinder_requests[request_id] = {
            spidertrons = spidertrons,
            request_tick = game.tick,
            destination = destination,
            bounding_box_size = bounding_box_size
        }
        for _, _spidertron in ipairs(spidertrons) do
            _spidertron.autopilot_destination = nil
        end
    end
    return new_destination
end

me.get_path_length = function(path)
    local distance = 0
    for i, waypoint in ipairs(path) do
        if i > 1 then
            distance = distance + custom_lib.distance_between(path[i - 1].position, waypoint.position)
        end
    end
    return distance
end

me.on_script_path_request_finished = function(event)
    local request = global.pathfinder_requests[event.id]
    if not request then
        return
    end
    local spidertrons = request.spidertrons
    local path = event.path
    if event.try_again_later then
        -- todo reschedule after n ticks, global.pathfinder_requests should have all required information
        debug_lib.VisualDebugText("pathfinding failed: engine is busy", spidertrons[1])
        request.try_again_later = true
    else
        if path then
            local clean_path = me.clean_linear_path(path)
            clean_path = me.clean_path_steps(clean_path)
            local distance = me.get_path_length(clean_path)
            log("path length " .. math.ceil(distance * 10) / 10)
            for _, spidertron in ipairs(spidertrons) do
                spidertron.autopilot_destination = nil
                local x = 1
                for i, waypoint in ipairs(clean_path) do
                    spidertron.add_autopilot_destination(waypoint.position)
                    debug_lib.VisualDebugCircle(waypoint.position, spidertron.surface, color_lib.color_alpha(color_lib.colors.pink, 0.2), tostring(x))
                    x = x + 1
                end
            end
        else
            debug_lib.VisualDebugText("pathfinder callback: path nil", spidertrons[1])
        end
        global.pathfinder_requests[event.id] = nil
    end
end

return me
