---@param chest string
---@param slot integer
---@param detailed? boolean
return function(chest, slot, detailed)
    return peripheral.call(chest, "getItemDetail", slot, detailed)
end
