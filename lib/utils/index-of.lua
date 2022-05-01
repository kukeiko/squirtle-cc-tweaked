---@param tbl table
---@param item unknown
---@return integer
return function(tbl, item)
    for i = 1, #tbl do
        if (tbl[i] == item) then
            return i
        end
    end

    return -1
end
