local me = {}

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

me.distance_between = function(position1, position2)
    return math.sqrt((position1.x - position2.x) ^ 2 + (position1.y - position2.y) ^ 2)
end

return me
