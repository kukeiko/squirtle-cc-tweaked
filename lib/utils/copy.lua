---@generic T: table
---@param tbl T
---@return T
return function(tbl)
    local copy = {}

    for k, v in pairs(tbl) do
        copy[k] = v
    end

    return copy
end
