local color_lib = require("script/color_lib")
---@class DebugUtil
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
me.VisualDebugText = function(message, entity, offset, ttl)
    if global.debug_toggle then
        rendering.draw_text {
            text = message or "",
            target = entity,
            filled = true,
            surface = entity.surface,
            time_to_live = (ttl * 60) or 60,
            target_offset = {0, (offset or 0)},
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

---@param position MapPosition
---@param surface LuaSurface
---@param color string
---@param radius double
---@param alpha float
---@param ttl uint?
me.VisualDebugCircle = function(position, surface, color, radius, alpha, ttl)
    if global.debug_toggle then
        if position then
            local message = "Circle"
            rendering.draw_circle {
                target = position,
                radius = radius,
                filled = true,
                surface = surface,
                time_to_live = ttl,
                color = (color_lib.color_alpha(color_lib.colors[color], alpha))
            }
        end
    end
end

---@param minimum MapPosition | LuaEntity
---@param maximum MapPosition | LuaEntity
---@param surface SurfaceIdentification
---@param color Color
me.draw_rectangle = function(minimum, maximum, surface, color)
    if global.debug_toggle then
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

        -- log("surface " .. (surface.name or surface.index) .. message)
        -- log("minimum:" .. serpent.block(minimum) .. ", maximum:" .. serpent.block(maximum))
    end
end

return me
