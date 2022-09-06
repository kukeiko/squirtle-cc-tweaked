---@param slot integer
---@param detailed? boolean
---@return ItemStack?
return function(slot, detailed)
    return turtle.getItemDetail(slot, detailed)
end
