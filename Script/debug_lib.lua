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
        rendering.draw_text {
            text = message,
            target = entity,
            filled = true,
            surface = entity.surface,
            time_to_live = 60,
            target_offset = {0, -2},
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

me.VisualDebugCircle = function(position, surface, color, text)
    if settings.global["constructron-debug-enabled"].value then
        if position then
            rendering.draw_circle {
                target = position,
                radius = 0.5,
                filled = true,
                surface = surface,
                time_to_live = 900,
                color = color
            }
            if text then
                rendering.draw_text {
                    text = text,
                    target = position,
                    filled = true,
                    surface = surface,
                    time_to_live = 900,
                    target_offset = {0, 0},
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
    end
end

return me
