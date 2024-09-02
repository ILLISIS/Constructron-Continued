local debug_lib = require("script/debug_lib")
local color_lib = require("script/color_lib")

local me = {}

-- function to update a combinator of a station
---@param station LuaEntity
---@param item_name string
---@param item_count integer
me.update_combinator = function(station, item_name, item_count)
    if not station or not station.valid or not item_name or not item_count then return end

    -- update master list
    local signals = global.station_combinators[station.unit_number]["signals"]

    signals[item_name] = ((signals[item_name] or 0) + item_count)

    if signals[item_name] < 0 then
        signals[item_name] = 0
    end

    -- update combinator signals
    local index = 2 -- there are garanteed to be at least 2 signals used for A and C
    local parameters = {}
    local surface_index = station.surface.index
    parameters[1] = {index = 1, signal = {type = "virtual", name = "signal-C"}, count = global.constructrons_count[surface_index]}
    parameters[2] = {index = 2, signal = {type = "virtual", name = "signal-A"}, count = global.available_ctron_count[surface_index]}
    for item, count in pairs(signals) do
        if index >= 100 then break end -- the combinator only has 100 slots
        index = index + 1
        parameters[index] = {
            index = index,
            signal = {
                type = "item",
                name = item
            },
            count = count
        }
    end

    global.station_combinators[station.unit_number]["signals"] = signals
    global.station_combinators[station.unit_number].entity.get_control_behavior().parameters = parameters
end


---@param constructron LuaEntity
---@param state ConstructronStatus
---@param value uint | boolean
me.set_constructron_status = function(constructron, state, value)
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
me.get_constructron_status = function(constructron, state)
    if global.constructron_statuses[constructron.unit_number] then
        return global.constructron_statuses[constructron.unit_number][state]
    end
    return nil
end

---@param surface_index uint
---@return table<uint, LuaEntity>
me.get_service_stations = function(surface_index) -- used to get all stations on a surface
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
me.get_closest_service_station = function(constructron) -- used to get the closest station on a surface
    local service_stations = me.get_service_stations(constructron.surface.index)
    for unit_number, station in pairs(service_stations) do
        if not station.valid then
            global.service_stations[unit_number] = nil -- could be redundant as entities are now registered
        end
    end
    local service_station_index = me.get_closest_object(service_stations, constructron.position) -- TODO this is duplicate from custom_lib
    return service_stations[service_station_index]
end

---@param constructron LuaEntity
---@param color_state "idle" | "construction" | "deconstruction" | "destroy" | "upgrade" | "repair" | "utility" | "logistic"
me.paint_constructron = function(constructron, color_state)
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
        elseif color_state == 'logistic' then
            constructron.color = color_lib.colors.yellow -- TODO: change color
        end
    end
end

---@param required_items ItemCounts
---@return integer
me.calculate_required_inventory_slot_count = function(required_items)
    local slots = 0
    local stack_size
    for name, count in pairs(required_items) do
        if not global.stack_cache[name] then
            stack_size = game.item_prototypes[name].stack_size
            global.stack_cache[name] = stack_size
        else
            stack_size = global.stack_cache[name]
        end
        slots = slots + math.ceil(count / stack_size)
    end
    return slots
end

-- Function to calculate the average speed of a Spidertron with equipment bonuses
me.calculate_spidertron_speed = function(spidertron)
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

---@param position MapPosition
---@return ChunkPosition
me.chunk_from_position = function(position)
    -- if a ghost entity found anywhere in the surface, we want to get the corresponding chunk
    -- so that we can fill constructron with all the other ghosts
    local chunk_index = {
        y = math.floor((position.y) / 80),
        x = math.floor((position.x) / 80)
    }
    return chunk_index
end

---@param chunk_index ChunkPosition
---@return MapPosition
me.position_from_chunk = function(chunk_index)
    local position = {
        y = chunk_index.y * 80,
        x = chunk_index.x * 80
    }
    return position
end

---@param chunk_index ChunkPosition
---@return Area
me.get_area_from_chunk = function(chunk_index)
    local area = {{
        y = chunk_index.y * 80,
        x = chunk_index.x * 80
    }, {
        y = (chunk_index.y + 1) * 80,
        x = (chunk_index.x + 1) * 80
    }}
    return area
end

---@param position MapPosition
---@param range number
---@return Area
me.get_area_from_position = function(position, range)
    local area = {{
        y = (position.y) - range,
        x = (position.x) - range
    }, {
        y = position.y + range,
        x = position.x + range
    }}
    return area
end

---@param area Area
---@param radius float
---@return MapPosition[]
me.calculate_construct_positions = function(area, radius)
    local height = math.max(area[2].y - area[1].y, 1) -- a single object has no width or height. which makes xpoint_count and ypoint_count zero. which means it won't be build.
    local width = math.max(area[2].x - area[1].x, 1) -- so, if either height or width are zero. they must be set to at least 1.
    local xpoints = {}
    local ypoints = {}
    local xpoint_count = math.ceil(width / radius / 2)
    local ypoint_count = math.ceil(height / radius / 2)

    if xpoint_count > 1 then
        for i = 1, xpoint_count do
            xpoints[i] = area[1].x + radius + (width - radius * 2) * (i - 1) / (xpoint_count - 1)
        end
    else
        xpoints[1] = area[1].x + width / 2
    end

    if ypoint_count > 1 then
        for j = 1, ypoint_count do
            ypoints[j] = area[1].y + radius + (height - radius * 2) * (j - 1) / (ypoint_count - 1)
        end
    else
        ypoints[1] = area[1].y + height / 2
    end

    local points = {}
    if xpoint_count < ypoint_count then
        for x = 1, xpoint_count do
            for y = 1, ypoint_count do
                table.insert(points, {
                    x = xpoints[x],
                    y = ypoints[(ypoint_count + 1) * (x % 2) + math.pow(-1, x % 2) * y]
                })
            end
        end
    else
        for y = 1, ypoint_count do
            for x = 1, xpoint_count do
                table.insert(points, {
                    y = ypoints[y],
                    x = xpoints[(xpoint_count + 1) * (y % 2) + math.pow(-1, y % 2) * x]
                })
            end
        end
    end
    return points
end

---@param objects LuaEntity[]
---@param position MapPosition
---@return integer?
me.get_closest_object = function(objects, position)
    -- actually returns object index or key rather than object.
    local min_distance ---@type number?
    local object_index ---@type integer?
    local iterator
    if not objects[1] then
        iterator = pairs
    else
        iterator = ipairs
    end
    for i, object in iterator(objects) do --[[@as integer]]
        local distance = me.distance_between(object.position, position)
        if not min_distance or (distance < min_distance) then
            min_distance = distance
            object_index = i
        end
    end
    return object_index
end

me.combine_tables = function(tables)
    local combined = {}
    for _, t in pairs(tables) do
        for k, v in pairs(t) do
            combined[k] = (combined[k] or 0) + v
        end
    end
    return combined
end

me.table_has_value = function(tab, val)
    if val == nil then
        return false
    end
    if not tab then
        return false
    end
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

-- [unused] previously used by pathfinder to merge tables
function me.merge(a, b)
    if type(a) == "table" and type(b) == "table" then
        for k, v in pairs(b) do
            if type(v) == "table" and type(a[k] or false) == "table" then
                me.merge(a[k], v)
            else
                a[k] = v
            end
        end
    end
    return a
end

---@param position1 MapPosition
---@param position2 MapPosition
---@return number
me.distance_between = function(position1, position2)
    return math.sqrt((position1.x - position2.x) ^ 2 + (position1.y - position2.y) ^ 2)
end

---@param to_split string
---@param sep string
---@return string[]
me.string_split = function(to_split, sep)
    local values = {}
    for str in string.gmatch(to_split, '([^'..sep..']+)') do
        table.insert(values, str)
    end
    return values
end

-- this function is used to get the first value of a LuaCustomTable
-- https://discord.com/channels/139677590393716737/306402592265732098/1279094347052220447
---@generic K,V
---@param lct LuaCustomTable<K,V>
---@return V
me.firstoflct = function(lct)
    for key, value in pairs(lct) do
        return value
    end
end

return me
