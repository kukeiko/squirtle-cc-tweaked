---@param modem string
---@return FoundInventory[]
return function(modem)
    ---@type FoundInventory[]
    local inventories = {}

    for _, name in pairs(peripheral.call(modem, "getNamesRemote") or {}) do
        local type = peripheral.getType(name)

        if type == "minecraft:chest" or type == "minecraft:furnace" then
            ---@type FoundInventory
            local inventory = {name = name, type = type}
            table.insert(inventories, inventory)
        end
    end

    return inventories
end
