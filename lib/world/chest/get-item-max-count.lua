---@type table<string, integer>
local itemMaxCounts = {}

---@param item string
---@param chest string
---@param slot integer
return function(item, chest, slot)
    if not itemMaxCounts[item] then
        ---@type ItemStack|nil
        local detailedStack = peripheral.call(chest, "getItemDetail", slot)

        if detailedStack then
            itemMaxCounts[item] = detailedStack.maxCount
        end
    end

    return itemMaxCounts[item]
end
