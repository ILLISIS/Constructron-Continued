local me = {}

me.table_has_value = function (tab, val)
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

return me
