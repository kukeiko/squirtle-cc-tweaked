---@param modem string
---@return string[]
return function(modem)
    ---@type string[]
    local inventories = {}

    for _, name in pairs(peripheral.call(modem, "getNamesRemote") or {}) do
        if peripheral.hasType(name, "minecraft:chest") then
            table.insert(inventories, name)
        end
    end

    return inventories
end
