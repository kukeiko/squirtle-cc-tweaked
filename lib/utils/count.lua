---@param tbl table
return function(tbl)
    local size = 0

    for _ in pairs(tbl) do
        size = size + 1
    end

    return size
end
