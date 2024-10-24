local debug_lib = require("script/debug_lib")
local color_lib = require("script/color_lib")

local me = {}

---@param constructron LuaEntity
---@param state ConstructronStatus
---@param value uint | boolean
me.set_constructron_status = function(constructron, state, value)
    if not (constructron and constructron.valid) then return end
    storage.constructron_statuses[constructron.unit_number][state] = value
    local surface_index = constructron.surface.index
    if value == true then
        storage.available_ctron_count[surface_index] = storage.available_ctron_count[surface_index] - 1
    elseif value == false then
        storage.available_ctron_count[surface_index] = storage.available_ctron_count[surface_index] + 1
    end
    me.update_ctron_combinator_signals(surface_index)
end

---@param constructron LuaEntity
---@param state ConstructronStatus
---@return uint | boolean?
me.get_constructron_status = function(constructron, state)
    if storage.constructron_statuses[constructron.unit_number] then
        return storage.constructron_statuses[constructron.unit_number][state]
    end
    return nil
end

---@param surface_index uint
---@return table<uint, LuaEntity>
me.get_service_stations = function(surface_index) -- used to get all stations on a surface
    ---@type table<uint, LuaEntity>
    local stations_on_surface = {}
    for s, station in pairs(storage.service_stations) do
        if station and station.valid then
            if (surface_index == station.surface.index) then
                stations_on_surface[station.unit_number] = station
            end
        else
            storage.service_stations[s] = nil
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
            storage.service_stations[unit_number] = nil -- could be redundant as entities are now registered
        end
    end
    local service_station_index = me.get_closest_object(service_stations, constructron.position)
    return service_stations[service_station_index]
end

local color_table = {
    ["idle"] = color_lib.colors.white,
    ["construction"] = color_lib.colors.blue,
    ["deconstruction"] = color_lib.colors.red,
    ["destroy"] = color_lib.colors.black,
    ["upgrade"] = color_lib.colors.green,
    ["repair"] = color_lib.colors.purple,
    ["utility"] = color_lib.colors.yellow,
    ["cargo"] = color_lib.colors.gray
}

---@param constructron LuaEntity
---@param job_type "idle" | "construction" | "deconstruction" | "destroy" | "upgrade" | "repair" | "utility" | "cargo"
me.paint_constructron = function(constructron, job_type)
    if not (constructron and constructron.valid) then return end
    local color = color_table[job_type]
    if not color then return end
    constructron.color = color
end

---@param required_items ItemCounts
---@return integer
me.calculate_required_inventory_slot_count = function(required_items)
    local slots = 0
    local stack_size
    for item_name, value in pairs(required_items) do
        for quality, count in pairs(value) do
            if not storage.stack_cache[item_name] then
                stack_size = prototypes.item[item_name].stack_size
                storage.stack_cache[item_name] = stack_size
            else
                stack_size = storage.stack_cache[item_name]
            end
            slots = slots + math.ceil(count / stack_size)
        end
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
                speed_multiplier = speed_multiplier * (1 + equipment.movement_bonus)
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

    for _, outer_table in pairs(tables) do
        for item_name, t_val in pairs(outer_table) do
            for quality, count in pairs(t_val) do
                combined[item_name] = combined[item_name] or {}
                combined[item_name][quality] = (combined[item_name][quality] or 0) + count
            end
        end
    end

    return combined
end

me.convert_to_item_list = function(list)
    local items = {}
    for _, item in pairs(list) do
        if item.name or item.value then
            local item_name = item.name or item.value.name
            local item_quality = item.quality or item.value.quality
            local item_count = item.count or item.max or item.min
            items[item_name] = items[item_name] or {}
            items[item_name][item_quality] = (items[item_name][item_quality] or 0) + item_count
        end
    end
    return items
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

---@param entity LuaEntity
me.setup_station_combinator = function(entity)
    local surface_index = entity.surface.index
    -- create the combinator entity
    local combinator = entity.surface.create_entity{
        name = "ctron-combinator",
        position = {(entity.position.x + 1), (entity.position.y + 1)},
        direction = defines.direction.west,
        force = entity.force,
        raise_built = true
    } ---@cast combinator -nil
    storage.ctron_combinators[entity.surface.index] = combinator
    -- register the combinator entity
    local combinator_reg_number = script.register_on_object_destroyed(storage.ctron_combinators[surface_index])
    storage.registered_entities[combinator_reg_number] = {
        name = "ctron-combinator",
        surface = surface_index
    }
    -- set signals
    me.update_ctron_combinator_signals(surface_index)
    -- connect stations to combinator
    local combinator_red_connector = combinator.get_wire_connector(defines.wire_connector_id.circuit_red, false)
    local combinator_green_connector = combinator.get_wire_connector(defines.wire_connector_id.circuit_green, false)
    local stations = me.get_service_stations(surface_index)
    for _, station in pairs(stations) do
        local station_red_connector = station.get_wire_connector(defines.wire_connector_id.circuit_red, false)
        local station_green_connector = station.get_wire_connector(defines.wire_connector_id.circuit_green, false)
        combinator_red_connector.connect_to(station_red_connector, false)
        combinator_green_connector.connect_to(station_green_connector, false)
    end
    return combinator
end

---@param combinator LuaEntity
---@param station LuaEntity
me.connect_station_to_combinator = function(combinator, station)
    local combinator_red_connector = combinator.get_wire_connector(defines.wire_connector_id.circuit_red, false)
    local combinator_green_connector = combinator.get_wire_connector(defines.wire_connector_id.circuit_green, false)
    local station_red_connector = station.get_wire_connector(defines.wire_connector_id.circuit_red, false)
    local station_green_connector = station.get_wire_connector(defines.wire_connector_id.circuit_green, false)
    combinator_red_connector.connect_to(station_red_connector, false)
    combinator_green_connector.connect_to(station_green_connector, false)
end

---@param surface_index uint
me.update_ctron_combinator_signals = function(surface_index)
    local combinator = storage.ctron_combinators[surface_index]
    if not combinator or not combinator.valid then return end
    local control_behavior = combinator.get_or_create_control_behavior()  --[[@as LuaConstantCombinatorControlBehavior]] ---@cast control_behavior -nil
    local filters = {
        [1] = {
            value = {
                type = "virtual",
                name = "signal-C",
                quality = "normal"
            },
            min = storage.constructrons_count[combinator.surface.index]
        },
        [2] = {
            value = {
                type = "virtual",
                name = "signal-A",
                quality = "normal"
            },
            min = storage.available_ctron_count[combinator.surface.index]
        }
    }
    control_behavior.sections[1].filters = filters
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
        return key
    end
end

-- ## Courtesy of flib
local suffix_list = {
    { "Y", 1e24 }, -- yotta
    { "Z", 1e21 }, -- zetta
    { "E", 1e18 }, -- exa
    { "P", 1e15 }, -- peta
    { "T", 1e12 }, -- tera
    { "G", 1e9 }, -- giga
    { "M", 1e6 }, -- mega
    { "k", 1e3 }, -- kilo
}

-- ## Courtesy of flib
--- Format a number for display, adding commas and an optional SI suffix.
--- Specify `fixed_precision` to display the number with the given width,
--- adjusting precision as necessary.
--- @param amount number
--- @param append_suffix boolean?
--- @param fixed_precision number?
--- @return string
function me.number(amount, append_suffix, fixed_precision)
    local suffix = ""
    if append_suffix then
        for _, data in ipairs(suffix_list) do
            if math.abs(amount) >= data[2] then
                amount = amount / data[2]
                suffix = "" .. data[1]
                break
            end
        end
        if not fixed_precision then
            amount = math.floor(amount * 10) / 10
        end
    end
    local formatted, k = tostring(amount), nil
    if fixed_precision then
        -- Show the number with fixed width precision
        local len_before = #tostring(math.floor(amount))
        local len_after = math.max(0, fixed_precision - len_before - 1)
        formatted = string.format("%." .. len_after .. "f", amount)
    end
    -- Add commas to result
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then
            break
        end
    end
    return formatted .. suffix
end

return me
