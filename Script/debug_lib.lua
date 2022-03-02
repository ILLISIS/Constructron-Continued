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

return me
