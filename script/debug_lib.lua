local color_lib = require("script/color_lib")
local me = {}

---@param message LocalisedString
me.DebugLog = function(message)
    if global.debug_toggle then
        game.print(message)
        -- log(message)
    end
end

---@param message LocalisedString
---@param entity LuaEntity
---@param offset float
---@param ttl uint
me.VisualDebugText = function(message, entity, offset, ttl, color)
    if global.debug_toggle then
        rendering.draw_text {
            text = message or "",
            target = entity,
            filled = true,
            surface = entity.surface,
            time_to_live = (ttl * 60) or 60,
            target_offset = {0, (offset or 0)},
            alignment = "center",
            color = color_lib.colors[color] or {
                r = 255,
                g = 255,
                b = 255,
                a = 255
            }
        }
    end
end


---@param position MapPosition
---@param surface LuaSurface
---@param color string
---@param radius integer
---@param ttl uint
me.VisualDebugCircle = function(position, surface, color, radius, ttl)
    if global.debug_toggle then
        rendering.draw_circle {
            target = position,
            radius = radius,
            filled = true,
            surface = surface,
            time_to_live = ttl,
            color = color_lib.colors[color]
        }
    end
end

---@param minimum MapPosition | LuaEntity
---@param maximum MapPosition | LuaEntity
---@param surface SurfaceIdentification
---@param color string
---@param filled boolean
---@param ttl uint
me.draw_rectangle = function(minimum, maximum, surface, color, filled, ttl)
    if global.debug_toggle then
        rendering.draw_rectangle {
            left_top = minimum,
            right_bottom = maximum,
            filled = filled,
            width = 4,
            surface = surface,
            time_to_live = ttl,
            color = color_lib.colors[color]
        }
    end
end

return me
