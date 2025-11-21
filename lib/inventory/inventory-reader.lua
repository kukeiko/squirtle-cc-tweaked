local Utils = require "lib.tools.utils"
local Inventory = require "lib.inventory.inventory"
local ItemApi = require "lib.inventory.item-api"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local readBuffer = require "lib.inventory.readers.read-buffer"
local readComposterConfiguration = require "lib.inventory.readers.read-composter-configuration"
local readComposterInput = require "lib.inventory.readers.read-composter-input"
local readDump = require "lib.inventory.readers.read-dump"
local readFurnace = require "lib.inventory.readers.read-furnace"
local readFurnaceConfiguration = require "lib.inventory.readers.read-furnace-configuration"
local readFurnaceOutput = require "lib.inventory.readers.read-furnace-output"
local readFurnaceInput = require "lib.inventory.readers.read-furnace-input"
local readIo = require "lib.inventory.readers.read-io"
local readQuickAccess = require "lib.inventory.readers.read-quick-access"
local readSilo = require "lib.inventory.readers.read-silo"
local readSiloInput = require "lib.inventory.readers.read-silo-input"
local readSiloOutput = require "lib.inventory.readers.read-silo-output"
local readStash = require "lib.inventory.readers.read-stash"
local readStorage = require "lib.inventory.readers.read-storage"
local readTrash = require "lib.inventory.readers.read-trash"
local readTurtleBuffer = require "lib.inventory.readers.read-turtle-buffer"
local readDispenser = require "lib.inventory.readers.read-dispenser"
local readTurtle = require "lib.inventory.readers.read-turtle"

local baseTypeLookup = {
    ["minecraft:chest"] = ItemApi.chest,
    ["minecraft:furna"] = ItemApi.furnace,
    ["minecraft:shulk"] = ItemApi.shulkerBox,
    ["minecraft:barre"] = ItemApi.barrel,
    ["minecraft:hoppe"] = ItemApi.hopper,
    ["minecraft:dispe"] = ItemApi.dispenser,
    ["turtle"] = "turtle"
}

---@class InventoryReader
local InventoryReader = {}

---@param nameTagName string
---@return string|nil, string|nil
local function parseNameAndLabel(nameTagName)
    local name, label = string.match(nameTagName, "^([%a%s%p]+)%s*@%s*([%a%s%p]+)$")

    if not name then
        return Utils.trim(nameTagName)
    end

    return Utils.trim(name), Utils.trim(label)
end

---@param name string
---@param stacks table<integer, ItemStack>
---@return integer? slot, string? name, string? label
local function findNameTag(name, stacks)
    for slot, stack in pairs(stacks) do
        if stack.name == "minecraft:name_tag" and stack.count == 1 and stack.nbt ~= nil then
            local stack = InventoryPeripheral.getStack(name, slot)

            if stack then
                return slot, parseNameAndLabel(stack.displayName)
            end
        end
    end
end

---@param name string
---@return Inventory
local function readIgnore(name)
    return Inventory.create(name, "ignore", {}, {}, false, nil, {})
end

---@param name string
---@return string?
local function getPeripheralBaseType(name)
    local peripheralType = peripheral.getType(name)

    if not peripheralType then
        return nil
    end

    return baseTypeLookup[string.sub(peripheralType, 1, 15)]
end

---@param name string
---@return boolean
function InventoryReader.isInventoryType(name)
    return getPeripheralBaseType(name) ~= nil
end

---@param name string
---@param autoStorage? boolean
---@return Inventory
function InventoryReader.read(name, autoStorage)
    local function create()
        local baseType = getPeripheralBaseType(name)

        if not baseType then
            error(string.format("unknown inventory base type for %s", name))
        end

        local stacks = InventoryPeripheral.getStacks(name)

        if baseType == ItemApi.furnace then
            return readFurnace(name, stacks)
        elseif baseType == ItemApi.shulkerBox then
            local shulker = readStorage(name, stacks)
            shulker.type = "shulker"

            return shulker
        elseif baseType == ItemApi.dispenser then
            return readDispenser(name, stacks)
        elseif baseType == "turtle" then
            return readTurtle(name, stacks)
        else
            local nameTagSlot, nameTagName, nameTagLabel = findNameTag(name, stacks)

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
                elseif nameTagName == "Furnace: Input" then
                    return readFurnaceInput(name, stacks, nameTagSlot)
                elseif nameTagName == "Furnace: Output" then
                    return readFurnaceOutput(name, stacks, nameTagSlot)
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
                elseif nameTagName == "Stash" and nameTagLabel ~= nil then
                    return readStash(name, stacks, nameTagSlot, nameTagLabel)
                elseif nameTagName == "Buffer" and nameTagLabel ~= nil then
                    return readTurtleBuffer(name, stacks, nameTagSlot, nameTagLabel)
                end
            elseif baseType == "minecraft:barrel" then
                return readTurtleBuffer(name, stacks)
            elseif baseType == "minecraft:hopper" then
                return readIgnore(name)
            else
                return readStorage(name, stacks, autoStorage)
            end
        end
    end

    return create()
end

return InventoryReader
