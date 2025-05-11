local color_lib = require("script/color_lib")
local me = {}

---@param message LocalisedString
me.DebugLog = function(message)
    if storage.debug_toggle then
        game.print(message)
        -- log(message)
    end
end

-- "temporarily permanent"
-- watch this survive the next refactor
local vertical_alignment = {
    [-1] = "top",
    [0] = "middle",
    [0.5] = "baseline",
    [1] = "bottom"
}

---@param message LocalisedString
---@param entity LuaEntity
---@param offset float?
---@param ttl uint?
---@param color string?
me.VisualDebugText = function(message, entity, offset, ttl, color)
    if storage.debug_toggle then
        rendering.draw_text {
            text = message or "",
            target = entity,
            filled = true,
            surface = entity.surface,
            time_to_live = (ttl * 60) or 60,
            vertical_alignment = vertical_alignment[offset] or "middle",
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
---@param surface LuaSurface|uint
---@param color string
---@param radius integer
---@param ttl uint
me.VisualDebugCircle = function(position, surface, color, radius, ttl)
    if storage.debug_toggle then
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
    if storage.debug_toggle then
        rendering.draw_rectangle {
            left_top = minimum,
            right_bottom = maximum,
            filled = filled,
            width = 4,
            surface = surface,
            time_to_live = ttl,
            color = color_lib.colors[color],
            draw_on_ground = true
        }
    end
end

me.VisualDebugLine = function (from, to, surface, color, ttl)
    if storage.debug_toggle then
        rendering.draw_line {
            width = 4,
            color = color_lib.colors[color],
            surface = surface,
            from = from,
            to = to,
            time_to_live = ttl
        }
    end
end

return me
