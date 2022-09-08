---@param inventories NetworkedInventory[]
---@return NetworkedInventoriesByType
return function(inventories)
    ---@type NetworkedInventoriesByType
    local byType = {storage = {}, io = {}, drain = {}, assigned = {}, furnace = {}}

    for _, inventory in ipairs(inventories) do
        table.insert(byType[inventory.type], inventory)
    end

    return byType
end
