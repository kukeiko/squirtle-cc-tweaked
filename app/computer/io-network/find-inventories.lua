local typeLookup = {["minecraft:chest"] = "minecraft:chest", ["minecraft:furna"] = "minecraft:furnace"}

---@param modem string
---@return FoundInventory[]
return function(modem)
    ---@type FoundInventory[]
    local inventories = {}

    for _, name in pairs(peripheral.call(modem, "getNamesRemote") or {}) do
        local invType = typeLookup[string.sub(name, 1, 15)]

        if invType then
            ---@type FoundInventory
            local inventory = {name = name, type = invType}
            table.insert(inventories, inventory)
        end
    end

    return inventories
end
