---@param inventories InputOutputInventory[]
---@return InputOutputInventoriesByType
return function(inventories)
    ---@type InputOutputInventoriesByType
    local byType = {storage = {}, io = {}, drain = {}, furnace = {}, silo = {}}

    for _, inventory in ipairs(inventories) do
        table.insert(byType[inventory.type], inventory)
    end

    return byType
end
