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

me.distance_between = function(position1, position2)
    return math.sqrt((position1.x - position2.x) ^ 2 + (position1.y - position2.y) ^ 2)
end

me.string_split = function(to_split,sep)
    local values = {}
    for str in string.gmatch(to_split, '([^'..sep..']+)') do
        table.insert(values, str)
    end
    return values
end

return me
