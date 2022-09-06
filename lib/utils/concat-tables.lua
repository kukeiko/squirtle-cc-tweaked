---@param ...table
---@return table
return function(...)
    local result = {}

    for _, tbl in pairs({...}) do
        for i = 1, #tbl do
            table.insert(result, tbl[i])
        end
    end

    return result
end
