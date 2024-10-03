local constructInventory = require "lib.inventory.construct-inventory"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local readBuffer = require "lib.inventory.readers.read-buffer"
local readComposterConfiguration = require "lib.inventory.readers.read-composter-configuration"
local readComposterInput = require "lib.inventory.readers.read-composter-input"
local readCrafter = require "lib.inventory.readers.read-crafter"
local readDump = require "lib.inventory.readers.read-dump"
local readFurnace = require "lib.inventory.readers.read-furnace"
local readFurnaceConfiguration = require "lib.inventory.readers.read-furnace-configuration"
local readFurnaceInput = require "lib.inventory.readers.read-furnace-input"
local readFurnaceOutput = require "lib.inventory.readers.read-furnace-output"
local readIo = require "lib.inventory.readers.read-io"
local readQuickAccess = require "lib.inventory.readers.read-quick-access"
local readSilo = require "lib.inventory.readers.read-silo"
local readSiloInput = require "lib.inventory.readers.read-silo-input"
local readSiloOutput = require "lib.inventory.readers.read-silo-output"
local readStash = require "lib.inventory.readers.read-stash"
local readStorage = require "lib.inventory.readers.read-storage"
local readTrash = require "lib.inventory.readers.read-trash"
local readTurtleBuffer = require "lib.inventory.readers.read-turtle-buffer"

local baseTypeLookup = {
    ["minecraft:chest"] = "minecraft:chest",
    ["minecraft:furna"] = "minecraft:furnace",
    ["minecraft:shulk"] = "minecraft:shulker_box",
    ["minecraft:barre"] = "minecraft:barrel",
    ["minecraft:hoppe"] = "minecraft:hopper"
}

---@class InventoryReader
local InventoryReader = {}

---@param name string
---@param stacks table<integer, ItemStack>
---@return integer? slot, string? name
local function findNameTag(name, stacks)
    for slot, stack in pairs(stacks) do
        if stack.name == "minecraft:name_tag" and stack.nbt ~= nil then
            local stack = InventoryPeripheral.getStack(name, slot)
            return slot, stack.displayName
        end
    end
end

---@param nameTagName string
---@return string|nil, string|nil
local function parseLabeledNameTag(nameTagName)
    return string.match(nameTagName, "(%w+): ([%w%s]+)")
end

---@param name string
---@return Inventory
local function readIgnore(name)
    return constructInventory(name, "ignore", {}, {})
end

---@param name string
---@return string?
local function getPeripheralBaseType(name)
    return baseTypeLookup[string.sub(peripheral.getType(name), 1, 15)]
end

---@param name string
---@return boolean
function InventoryReader.isInventoryType(name)
    return getPeripheralBaseType(name) ~= nil
end

---@param name string
---@param expected? InventoryType
---@return Inventory
function InventoryReader.read(name, expected)
    local function create()
        local baseType = getPeripheralBaseType(name)

        if not baseType then
            error(string.format("unknown inventory base type for %s", name))
        end

        local stacks = InventoryPeripheral.getStacks(name)

        if baseType == "minecraft:furnace" then
            return readFurnace(name, stacks)
        elseif baseType == "minecraft:shulker_box" then
            local shulker = readStorage(name, stacks)
            shulker.type = "shulker"

            return shulker
        else
            local nameTagSlot, nameTagName = findNameTag(name, stacks)

            if nameTagSlot and nameTagName then
                stacks[nameTagSlot] = nil

                if nameTagName == "I/O" then
                    return readIo(name, stacks, nameTagSlot)
                elseif nameTagName == "Drain" or nameTagName == "Dump" then
                    return readDump(name, stacks, nameTagSlot)
                elseif nameTagName == "Silo" then
                    return readSilo(name, stacks, nameTagSlot)
                elseif nameTagName == "Silo: Input" then
                    return readSiloInput(name, stacks, nameTagSlot)
                elseif nameTagName == "Silo: Output" then
                    return readSiloOutput(name, stacks, nameTagSlot)
                elseif nameTagName == "Crafter" then
                    return readCrafter(name, stacks, nameTagSlot)
                elseif nameTagName == "Furnace: Input" then
                    return readFurnaceOutput(name, stacks, nameTagSlot)
                elseif nameTagName == "Furnace: Output" then
                    return readFurnaceInput(name, stacks, nameTagSlot)
                elseif nameTagName == "Furnace: Config" then
                    return readFurnaceConfiguration(name, stacks, nameTagSlot)
                elseif nameTagName == "Quick Access" then
                    return readQuickAccess(name, stacks, nameTagSlot)
                elseif nameTagName == "Composter: Config" then
                    return readComposterConfiguration(name, stacks, nameTagSlot)
                elseif nameTagName == "Composter: Input" then
                    return readComposterInput(name, stacks, nameTagSlot)
                elseif nameTagName == "Trash" then
                    return readTrash(name, stacks, nameTagSlot)
                elseif nameTagName == "Buffer" then
                    return readBuffer(name, stacks, nameTagSlot)
                else
                    local tagName, label = parseLabeledNameTag(nameTagName)

                    if tagName == "Stash" and label ~= nil then
                        return readStash(name, stacks, nameTagSlot, label)
                    elseif tagName == "Buffer" and label ~= nil then
                        return readTurtleBuffer(name, stacks, nameTagSlot, label)
                    end
                end
            elseif baseType == "minecraft:barrel" or baseType == "minecraft:hopper" then
                return readIgnore(name)
            else
                return readStorage(name, stacks)
            end
        end
    end

    local inventory = create()

    if expected and not inventory then
        error(string.format("expected %s to be of type %s, but found nothing", name, expected))
    elseif expected and inventory.type ~= expected then
        error(string.format("expected %s to be of type %s, but got %s", name, expected, inventory.type))
    else
        return inventory
    end
end

return InventoryReader
