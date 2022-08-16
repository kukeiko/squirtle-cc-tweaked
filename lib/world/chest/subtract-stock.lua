local copy = require "utils.copy"

---@param a table<string, integer>
---@param b table<string, integer>
---@return table<string, integer>
return function(a, b)
    local result = copy(a)

    for item, stock in pairs(b) do
        result[item] = (result[item] or 0) - stock
    end

    return result
end
