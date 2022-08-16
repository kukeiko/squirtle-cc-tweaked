---@param from string
---@param to string
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
return function(from, to, fromSlot, limit, toSlot)
    return peripheral.call(from, "pushItems", to, fromSlot, limit, toSlot)
end
