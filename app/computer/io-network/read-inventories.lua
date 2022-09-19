local getStacks = require "inventory.get-stacks"
local findNameTag = require "inventory.find-name-tag"
local printProgress = require "io-network.print-progress"
local readInputOutputChest = require "io-network.read-io-chest"
local readStorageChest = require "io-network.read-storage-chest"
local readDrainInventory = require "io-network.read-drain-inventory"
local readFurnace = require "io-network.read-furnace"
local readSiloInventory = require "io-network.read-silo-inventory"

---@param found FoundInventory[]
---@return NetworkedInventory[]
return function(found)
    ---@type NetworkedInventory[]
    local inventories = {}
    print("reading", #found, "inventories...")
    local x, y = printProgress(0, #found)

    for i, foundInventory in ipairs(found) do
        local name = foundInventory.name

        if foundInventory.type == "minecraft:furnace" then
            table.insert(inventories, readFurnace(name))
        else
            local stacks = getStacks(name)
            local nameTagSlot, nameTagName = findNameTag(name, {"I/O", "Drain"}, stacks)

            if nameTagSlot and nameTagName then
                if nameTagName == "I/O" then
                    table.insert(inventories, readInputOutputChest(name, stacks, nameTagSlot))
                elseif nameTagName == "Drain" then
                    table.insert(inventories, readDrainInventory(name, {nameTagSlot}))
                elseif nameTagName == "Silo" then
                    table.insert(inventories, readSiloInventory(name, {nameTagSlot}))
                end
            else
                table.insert(inventories, readStorageChest(name, stacks))
            end
        end

        x, y = printProgress(i, #found, x, y)
    end

    return inventories
end
