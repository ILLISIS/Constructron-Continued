local debug_lib = require("__Constructron-Continued__.script.debug_lib")
local color_lib = require("__Constructron-Continued__.script.color_lib")
local collision_mask_util_extended = require("__Constructron-Continued__.script.collision-mask-util-control")

local me = {}

me.init = function()
    global.pathfinder_requests = global.pathfinder_requests or {}
    for key,request in pairs(global.pathfinder_requests) do
        if ((game.tick -request.request_tick) > 60 *60 ) then -- one minute
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

me.request_path = function(spidertrons, pathfinding_proxy_entity_name, goal)
    local spidertron = spidertrons[1]
    local new_start, new_goal
    if spidertron.valid then
        local surface = spidertron.surface
        new_start = surface.find_non_colliding_position(pathfinding_proxy_entity_name, spidertron.position, 32, 0.1, false)
        new_goal = surface.find_non_colliding_position(pathfinding_proxy_entity_name, goal, 32, 0.1, false)
        debug_lib.VisualDebugCircle(goal, surface, color_lib.color_alpha(color_lib.colors.red, 0.2))
        debug_lib.VisualDebugCircle(new_goal, surface, color_lib.color_alpha(color_lib.colors.green, 0.2))
        if new_goal and new_start then
            local pathing_collision_mask = {"water-tile",  "consider-tile-transitions", "colliding-with-tiles-only"}
            if game.active_mods["space-exploration"] then
                local spaceship_collision_layer = collision_mask_util_extended.get_named_collision_mask("moving-tile")
                local empty_space_collision_layer = collision_mask_util_extended.get_named_collision_mask("empty-space-tile")
                table.insert(pathing_collision_mask, spaceship_collision_layer)
                table.insert(pathing_collision_mask, empty_space_collision_layer)
            end
            local request_id = surface.request_path {
                bounding_box = {{-0.5, -0.5}, {0.5, 0.5}},
                collision_mask = pathing_collision_mask,
                start = new_start,
                goal = new_goal,
                force = spidertron.force,
                pathfinding_flags = {
                    cache = false,
                    low_priority = true
                }
            }
            global.pathfinder_requests[request_id] = {
                spidertrons = spidertrons
                ,request_tick = game.tick
            }
            for _, _spidertron in ipairs(spidertrons) do
                _spidertron.autopilot_destination = nil
            end
        else
            debug_lib.VisualDebugText("pathfinding request failed: start or target not reachable", spidertron)
            return nil
        end
    end
    return new_goal
end

me.on_script_path_request_finished = function(event)
    local request = global.pathfinder_requests[event.id]
    if not request then
        return
    end
    local spidertrons = request.spidertrons
    local path = event.path
    if event.try_again_later then
        debug_lib.VisualDebugText("pathfinding failed: engine is busy", spidertrons[1])
    elseif path then
        local clean_path = me.clean_linear_path(path)
        for _, spidertron in ipairs(spidertrons) do
            spidertron.autopilot_destination = nil
            local x = 0
            for i, waypoint in ipairs(clean_path) do
                spidertron.add_autopilot_destination(waypoint.position)
                debug_lib.VisualDebugCircle(waypoint.position, spidertron.surface, color_lib.color_alpha(color_lib.colors.pink, 0.2), tostring(x))
                x = x + 1
            end
        end
        global.pathfinder_requests[event.id] = nil
    elseif not path then
        debug_lib.VisualDebugText("pathfinder callback: path nil", spidertrons[1])
        global.pathfinder_requests[event.id] = nil
    end
end

return me
