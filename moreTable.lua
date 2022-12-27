local moreTable = {
contains = function (array, value)
for i, v in ipairs(array) do
    if v == value then
        return true
    end
end
for k, v in pairs(array) do
    if k == value then
        return true
    end
end
return false
end,
index = function (array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return nil
end,
keys = function (array)
    local keys = {}
    for k, v in pairs(array) do
        table.insert(keys, k)
    end
    return keys
end,
values = function (array)
    local values = {}
    for k, v in pairs(array) do
        table.insert(values, v)
    end
    return values
end
}

return moreTable