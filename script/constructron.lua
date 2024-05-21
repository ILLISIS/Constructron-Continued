require("util")

local chunk_util = require("script/chunk_util")
local color_lib = require("script/color_lib")

---@module "chunk_util"
---@module "debug_lib"
---@module "color_lib"

local ctron = {}

--===========================================================================--
-- abilities
--===========================================================================--

-- Function to calculate the average speed of a Spidertron with equipment bonuses
ctron.calculate_spidertron_speed = function(spidertron)
    -- Base speed of the Spidertron
    local base_speed = 0.18
    -- Initialize total speed multiplier
    local speed_multiplier = 1.0
    -- Check if the Spidertron has an equipment grid
    if spidertron.grid then
        -- Iterate through the equipment grid
        for _, equipment in pairs(spidertron.grid.equipment) do
            -- Check if the equipment is an exoskeleton
            if equipment.type == "movement-bonus-equipment" then
                -- Multiply the speed multiplier by the exoskeleton's movement bonus
                speed_multiplier = speed_multiplier * (1 + equipment.prototype.movement_bonus)
            end
        end
    end
    -- Calculate the total speed with bonuses
    local total_speed = base_speed * speed_multiplier
    return total_speed
end


---@param constructron LuaEntity
---@param state ConstructronStatus
---@param value uint | boolean
ctron.set_constructron_status = function(constructron, state, value)
    if constructron and constructron.valid then
    if global.constructron_statuses[constructron.unit_number] then
        global.constructron_statuses[constructron.unit_number][state] = value
    else
        global.constructron_statuses[constructron.unit_number] = {}
        global.constructron_statuses[constructron.unit_number][state] = value
        end
    end
end

---@param constructron LuaEntity
---@param state ConstructronStatus
---@return uint | boolean?
ctron.get_constructron_status = function(constructron, state)
    if global.constructron_statuses[constructron.unit_number] then
        return global.constructron_statuses[constructron.unit_number][state]
    end
    return nil
end

---@param surface_index uint
---@return table<uint, LuaEntity>
ctron.get_service_stations = function(surface_index) -- used to get all stations on a surface
    ---@type table<uint, LuaEntity>
    local stations_on_surface = {}
    for s, station in pairs(global.service_stations) do
        if station and station.valid then
            if (surface_index == station.surface.index) then
                stations_on_surface[station.unit_number] = station
            end
        else
            global.service_stations[s] = nil
        end
    end
    return stations_on_surface or {}
end

---@param constructron LuaEntity
---@return LuaEntity
ctron.get_closest_service_station = function(constructron) -- used to get the closest station on a surface
    local service_stations = ctron.get_service_stations(constructron.surface.index)
    for unit_number, station in pairs(service_stations) do
        if not station.valid then
            global.service_stations[unit_number] = nil -- could be redundant as entities are now registered
        end
    end
    local service_station_index = chunk_util.get_closest_object(service_stations, constructron.position)
    return service_stations[service_station_index]
end

---@param constructron LuaEntity
---@param color_state "idle" | "construction" | "deconstruction" | "destroy" | "upgrade" | "repair" | "utility"
ctron.paint_constructron = function(constructron, color_state)
    if constructron and constructron.valid then
        if color_state == 'idle' then
            constructron.color = color_lib.colors.white
        elseif color_state == 'construction' then
            constructron.color = color_lib.colors.blue
        elseif color_state == 'deconstruction' then
            constructron.color = color_lib.colors.red
        elseif color_state == 'destroy' then
            constructron.color = color_lib.colors.black
        elseif color_state == 'upgrade' then
            constructron.color = color_lib.colors.green
        elseif color_state == 'repair' then
            constructron.color = color_lib.colors.purple
        elseif color_state == 'utility' then
            constructron.color = color_lib.colors.yellow
        end
    end
end

return ctron
