local me = {}

---@param position1 MapPosition
---@param position2 MapPosition
---@return number?
me.distance_between = function(position1, position2)
    if position1 and position2 then
        return math.sqrt((position1.x - position2.x) ^ 2 + (position1.y - position2.y) ^ 2)
    end
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

return me
