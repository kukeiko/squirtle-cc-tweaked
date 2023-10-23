local Inventory = require "inventory.inventory"
local readInputOutputChest = require "io-network.read.read-io-chest"
local readStorageChest = require "io-network.read.read-storage-chest"
local readDrainInventory = require "io-network.read.read-drain-inventory"
local readFurnace = require "io-network.read.read-furnace"
local readSiloInventory = require "io-network.read.read-silo-inventory"

local baseTypeLookup = {
    ["minecraft:chest"] = "minecraft:chest",
    ["minecraft:furna"] = "minecraft:furnace",
    ["minecraft:shulk"] = "minecraft:shulker_box"
}

---@param name string
---@return InputOutputInventory?
return function(name)
    local baseType = baseTypeLookup[string.sub(name, 1, 15)]

    if not baseType then
        return nil
    end

    if baseType == "minecraft:furnace" then
        return readFurnace(name)
    elseif baseType == "minecraft:shulker_box" then
        local shulker = readStorageChest(name, Inventory.getStacks(name))
        shulker.type = "shulker"

        return shulker
    else
        local stacks = Inventory.getStacks(name)
        local nameTagSlot, nameTagName = Inventory.findNameTag(name, {"I/O", "Drain"}, stacks)

        if nameTagSlot and nameTagName then
            if nameTagName == "I/O" then
                return readInputOutputChest(name, stacks, nameTagSlot)
            elseif nameTagName == "Drain" then
                return readDrainInventory(name, {nameTagSlot})
            elseif nameTagName == "Silo" then
                return readSiloInventory(name, {nameTagSlot})
            end
        else
            return readStorageChest(name, stacks)
        end
    end
end
