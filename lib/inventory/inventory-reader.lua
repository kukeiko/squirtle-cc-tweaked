local Utils = require "utils"
local InventoryPeripheral = require "inventory.inventory-peripheral"

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
---@param tagNames table<string>
---@param stacks table<integer, ItemStack>
---@return integer? slot, string? name
local function findNameTag(name, tagNames, stacks)
    for slot, stack in pairs(stacks) do
        if stack.name == "minecraft:name_tag" then
            local stack = InventoryPeripheral.getStack(name, slot)

            if Utils.indexOf(tagNames, stack.displayName) > 0 then
                return slot, stack.displayName
            end
        end
    end
end

---@param stacks ItemStacks
---@return boolean
local function isMonoTypeStacks(stacks)
    if Utils.isEmpty(stacks) then
        return false
    end

    local name

    for _, stack in pairs(stacks) do
        if not name then
            name = stack.name
        elseif name and stack.name ~= name then
            return false
        end
    end

    return true
end

---@param name string
---@param type InventoryType
---@param stacks ItemStacks
---@param slots table<integer, InventorySlot>
---@param allowAllocate? boolean
---@return Inventory
function construct(name, type, stacks, slots, allowAllocate)
    ---@type Inventory
    local inventory = {name = name, type = type, stacks = stacks, allowAllocate = allowAllocate or false, slots = slots}

    return inventory
end

---@param name string
---@param stacks table<integer, ItemStack>
---@return Inventory
local function createStorage(name, stacks)
    ---@type table<integer, InventorySlot>
    local slots = {}

    if isMonoTypeStacks(stacks) then
        local first = Utils.first(stacks)
        ---@type ItemStack
        local template = {name = first.name, count = 0, displayName = first.displayName, maxCount = first.maxCount}

        for index = 1, InventoryPeripheral.getSize(name) do
            ---@type InventorySlot
            -- [todo] find references on "tags" doesn't work? (when using it on the type in inventory-elemental.lua file)
            local slot = {index = index, tags = {input = true, output = true}, permanent = true}
            slots[index] = slot
            local stack = stacks[index]

            if stack then
                stack.maxCount = stack.maxCount - 1
                stack.count = stack.count - 1
            else
                stacks[index] = Utils.copy(template)
            end
        end
    else
        for index, stack in pairs(stacks) do
            slots[index] = {index = index, tags = {input = true, output = true}, permanent = true}
            stack.maxCount = stack.maxCount - 1
            stack.count = stack.count - 1
        end
    end

    return construct(name, "storage", stacks, slots, false)
end

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
local function createQuickAccess(name, stacks, nameTagSlot)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot, stack in pairs(stacks) do
        if slot ~= nameTagSlot then
            slots[slot] = {index = slot, tags = {input = true}}
        end
    end

    return construct(name, "quick-access", stacks, slots)
end

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
local function createIo(name, stacks, nameTagSlot)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot, stack in pairs(stacks) do
        if slot ~= nameTagSlot then
            stack.count = stack.count - 1
            stack.maxCount = stack.maxCount - 1

            if slot < nameTagSlot then
                slots[slot] = {index = slot, permanent = true, tags = {input = true}}
            elseif slot > nameTagSlot then
                slots[slot] = {index = slot, permanent = true, tags = {output = true}}
            end
        else
            slots[slot] = {index = slot, tags = {nameTag = true}}
        end
    end

    return construct(name, "io", stacks, slots)
end

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
local function createDrain(name, stacks, nameTagSlot)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot = 1, InventoryPeripheral.getSize(name) do
        ---@type InventorySlotTags
        local tags = {}

        if slot == nameTagSlot then
            tags.nameTag = true
        else
            tags.output = true
        end

        slots[slot] = {index = slot, tags = tags}
    end

    return construct(name, "drain", stacks, slots)
end

---@param name string
---@param stacks table<integer, ItemStack>
---@return Inventory
local function createBuffer(name, stacks)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot = 1, InventoryPeripheral.getSize(name) do
        ---@type InventorySlotTags
        local tags = {output = true, input = true}
        slots[slot] = {index = slot, tags = tags}
    end

    return construct(name, "buffer", stacks, slots, true)
end

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
local function createSilo(name, stacks, nameTagSlot)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot = 1, InventoryPeripheral.getSize(name) do
        ---@type InventorySlotTags
        local tags = {}

        if slot == nameTagSlot then
            tags.nameTag = true
        else
            tags.output = true
        end

        slots[slot] = {index = slot, tags = tags}
    end

    return construct(name, "silo", stacks, slots)
end

---@param name string
---@param stacks table<integer, ItemStack>
---@return Inventory
local function createFurnace(name, stacks)
    ---@type table<integer, InventorySlot>
    local slots = {}

    slots[1] = {index = 1, tags = {input = true}}
    slots[2] = {index = 2, tags = {fuel = true}}
    slots[3] = {index = 3, tags = {output = true}}

    return construct(name, "furnace", {stacks[1], stacks[2], stacks[3]}, slots, true)
end

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
local function createFurnaceOutput(name, stacks, nameTagSlot)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot = 1, InventoryPeripheral.getSize(name) do
        ---@type InventorySlotTags
        local tags = {}

        if slot == nameTagSlot then
            tags.nameTag = true
        else
            tags.input = true
            tags.output = true
        end

        slots[slot] = {index = slot, tags = tags}
    end

    return construct(name, "furnace-output", stacks, slots, true)
end

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
local function createFurnaceInput(name, stacks, nameTagSlot)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot = 1, InventoryPeripheral.getSize(name) do
        ---@type InventorySlotTags
        local tags = {}

        if slot == nameTagSlot then
            tags.nameTag = true
        else
            tags.output = true
        end

        slots[slot] = {index = slot, tags = tags}
    end

    return construct(name, "furnace-input", stacks, slots)
end

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
local function createFurnaceConfiguration(name, stacks, nameTagSlot)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot = 1, InventoryPeripheral.getSize(name) do
        ---@type InventorySlotTags
        local tags = {}

        if slot == nameTagSlot then
            tags.nameTag = true
        else
            tags.configuration = true
        end

        slots[slot] = {index = slot, tags = tags}
    end

    return construct(name, "furnace-config", stacks, slots)
end

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
local function createComposterInput(name, stacks, nameTagSlot)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot = 1, InventoryPeripheral.getSize(name) do
        ---@type InventorySlotTags
        local tags = {}

        if slot == nameTagSlot then
            tags.nameTag = true
        else
            tags.input = true
        end

        slots[slot] = {index = slot, tags = tags}
    end

    return construct(name, "composter-input", stacks, slots, true)
end

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
local function createComposterConfiguration(name, stacks, nameTagSlot)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot = 1, InventoryPeripheral.getSize(name) do
        ---@type InventorySlotTags
        local tags = {}

        if slot == nameTagSlot then
            tags.nameTag = true
        else
            tags.configuration = true
        end

        slots[slot] = {index = slot, tags = tags}
    end

    return construct(name, "composter-config", stacks, slots)
end

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
local function createTrash(name, stacks, nameTagSlot)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot = 1, InventoryPeripheral.getSize(name) do
        ---@type InventorySlotTags
        local tags = {}

        if slot == nameTagSlot then
            tags.nameTag = true
        else
            tags.input = true
            tags.output = true
        end

        slots[slot] = {index = slot, tags = tags}
    end

    return construct(name, "trash", stacks, slots, true)
end

---@param name string
---@return Inventory
local function createIgnore(name)
    return construct(name, "ignore", {}, {})
end

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
local function createCrafterInventory(name, stacks, nameTagSlot)
    local inputSlotOffset = 3
    local outputSlotOffset = 6

    ---@param slots table<integer, InventorySlot>
    ---@param offset integer
    ---@param tags InventorySlotTags
    local function fillSlots(slots, offset, tags)
        for i = 1, 9 do
            local line = math.ceil(i / 3)
            local offsetRight = (line - 1) * (9 - (offset + 3))
            local slot = i + (offset * line) + offsetRight

            slots[slot] = {index = slot, tags = Utils.clone(tags)}
        end
    end

    -- [todo] nameTag slot handling missing - mainly because current crafter code
    -- changes position of it, and I have not yet decided how I wanna deal with that.
    ---@type table<integer, InventorySlot>
    local slots = {}
    fillSlots(slots, inputSlotOffset, {input = true})
    fillSlots(slots, outputSlotOffset, {output = true})

    return construct(name, "crafter", stacks, slots, true)
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
            return createFurnace(name, stacks)
        elseif baseType == "minecraft:shulker_box" then
            local shulker = createStorage(name, stacks)
            shulker.type = "shulker"

            return shulker
        else
            local tagNames = {
                "I/O",
                "Drain",
                "Dump",
                "Silo",
                "Crafter",
                "Furnace: Input",
                "Furnace: Output",
                "Furnace: Config",
                "Quick Access",
                "Composter: Input",
                "Composter: Config",
                "Trash"
            }
            local nameTagSlot, nameTagName = findNameTag(name, tagNames, stacks)

            if nameTagSlot and nameTagName then
                stacks[nameTagSlot] = nil

                if nameTagName == "I/O" then
                    return createIo(name, stacks, nameTagSlot)
                elseif nameTagName == "Drain" or nameTagName == "Dump" then
                    return createDrain(name, stacks, nameTagSlot)
                elseif nameTagName == "Silo" then
                    return createSilo(name, stacks, nameTagSlot)
                elseif nameTagName == "Crafter" then
                    return createCrafterInventory(name, stacks, nameTagSlot)
                elseif nameTagName == "Furnace: Input" then
                    return createFurnaceInput(name, stacks, nameTagSlot)
                elseif nameTagName == "Furnace: Output" then
                    return createFurnaceOutput(name, stacks, nameTagSlot)
                elseif nameTagName == "Furnace: Config" then
                    return createFurnaceConfiguration(name, stacks, nameTagSlot)
                elseif nameTagName == "Quick Access" then
                    return createQuickAccess(name, stacks, nameTagSlot)
                elseif nameTagName == "Composter: Config" then
                    return createComposterConfiguration(name, stacks, nameTagSlot)
                elseif nameTagName == "Composter: Input" then
                    return createComposterInput(name, stacks, nameTagSlot)
                elseif nameTagName == "Trash" then
                    return createTrash(name, stacks, nameTagSlot)
                end
            elseif baseType == "minecraft:barrel" then
                return createBuffer(name, stacks)
            elseif baseType == "minecraft:hopper" then
                return createIgnore(name)
            else
                return createStorage(name, stacks)
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
