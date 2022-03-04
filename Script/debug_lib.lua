local me = {}

me.DebugLog = function(message)
    if settings.global["constructron-debug-enabled"].value then
        game.print(message)
        log(message)
    end
end

me.VisualDebugText = function(message, entity)
    if not entity or not entity.valid then
        return
    end
    if settings.global["constructron-debug-enabled"].value then
        local offset = {0, (math.random() * 3 - 1.5) - 2}
        rendering.draw_text {
            text = message,
            target = entity,
            filled = true,
            surface = entity.surface,
            time_to_live = 60,
            target_offset = offset,
            alignment = "center",
            color = {
                r = 255,
                g = 255,
                b = 255,
                a = 255
            }
        }
        log("surface " .. (entity.surface.name or entity.surface.index) .. " - " .. entity.name .. " #" .. entity.unit_number .. " (x:" .. (entity.position.x) .. ",y:" .. (entity.position.y) .. "):" .. message)
    end
end

me.VisualDebugCircle = function(position, surface, color, text)
    if settings.global["constructron-debug-enabled"].value then
        if position then
            local message = "Circle"
            rendering.draw_circle {
                target = position,
                radius = 0.5,
                filled = true,
                surface = surface,
                time_to_live = 900,
                color = color
            }
            if text then
                message = message .. "(" .. text .. ")"
                rendering.draw_text {
                    text = text,
                    target = {position.x,position.y-0.25},
                    filled = true,
                    surface = surface,
                    time_to_live = 900,
                    alignment = "center",
                    color = {
                        r = 255,
                        g = 255,
                        b = 255,
                        a = 255
                    }
                }
            end
            log("surface " .. (surface.name or surface.index) .. " (x:" .. (position.x) .. ",y:" .. (position.y) .. "):" .. message)
        end
    end
end

me.draw_rectangle = function(minimum, maximum, surface, color)
    if settings.global["constructron-debug-enabled"].value then
        local message = "rectangle"
        local inner_color = {
            r = color.r,
            g = color.g,
            b = color.b,
            a = 0.1
        }

        rendering.draw_rectangle {
            left_top = minimum,
            right_bottom = maximum,
            filled = true,
            surface = surface,
            time_to_live = 600,
            color = inner_color
        }

        rendering.draw_rectangle {
            left_top = minimum,
            right_bottom = maximum,
            width = 3,
            filled = false,
            surface = surface,
            time_to_live = 600,
            color = color
        }

        log("surface " .. (surface.name or surface.index) .. message)
        log("minimum:" .. serpent.block(minimum) .. ", maximum:" .. serpent.block(maximum))
    end
end

return me
