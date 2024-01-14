local Utils = require "utils"
local InventoryElemental = require "inventory.inventory-elemental"
local InventoryBasic = require "inventory.inventory-basic"

-- [note] refuel numbers not actually used
local fuelItems = {["minecraft:lava_bucket"] = 1000, ["minecraft:coal"] = 80, ["minecraft:charcoal"] = 80, ["minecraft:coal_block"] = 800}

local baseTypeLookup = {
    ["minecraft:chest"] = "minecraft:chest",
    ["minecraft:furna"] = "minecraft:furnace",
    ["minecraft:shulk"] = "minecraft:shulker_box"
}

---@class InventoryAdvanced : InventoryBasic
local InventoryAdvanced = {}
setmetatable(InventoryAdvanced, {__index = InventoryBasic})

local function getDefaultRate()
    return 8
end

---@param stacks table<integer, ItemStack>
---@param item string
---@return integer? slot, ItemStack? stack
local function nextFromStack(stacks, item)
    for slot, stack in pairs(stacks) do
        if stack.count > 0 and stack.name == item then
            return slot, stack
        end
    end
end

---@param stacks table<integer, ItemStack>
---@param item string
---@return integer? slot, ItemStack? stack
local function nextToStack(stacks, item, sample, size)
    for slot, stack in pairs(stacks) do
        if stack.count < stack.maxCount and stack.name == item then
            return slot, stack
        end
    end
end

---@param inventory Inventory
---@param sample ItemStack
---@return integer? slot, ItemStack? stack
local function allocateNextFurnaceToStack(inventory, sample)
    if fuelItems[sample.name] and not inventory.stacks[2] then
        -- local fuelStack = inventory.stacks[2] -- [todo] what? we just checked for "not inventory.stacks[2]"

        local fuelStack = Utils.clone(sample)
        fuelStack.count = 0
        inventory.stacks[2] = fuelStack

        if not inventory.stock[sample.name] then
            inventory.stock[sample.name] = Utils.clone(sample)
            inventory.stock[sample.name].count = 0
        end

        return 2, fuelStack
    elseif not inventory.stacks[1] then
        local stack = Utils.clone(sample)
        stack.count = 0
        inventory.stacks[1] = stack

        if not inventory.stock[sample.name] then
            inventory.stock[sample.name] = Utils.clone(sample)
            inventory.stock[sample.name].count = 0
        end

        return 1, stack
    end
end

---@param inventory Inventory
---@param sample ItemStack
---@return integer? slot, ItemStack? stack
local function allocateNextToStack(inventory, sample)
    if InventoryBasic.isFurnace(inventory) then
        return allocateNextFurnaceToStack(inventory, sample)
    end

    if #inventory.slots > 0 then
        for _, slot in pairs(inventory.slots) do
            local stack = inventory.stacks[slot]

            if not stack then
                ---@type ItemStack
                stack = Utils.copy(sample)
                stack.count = 0
                inventory.stacks[slot] = stack

                local stock = inventory.stock[sample.name]

                if not stock then
                    ---@type ItemStack
                    stock = Utils.copy(sample)
                    stock.count = 0
                    stock.maxCount = 0
                    inventory.stock[sample.name] = stock
                end

                -- [todo] i think this screws up lava bucket transfer
                stock.maxCount = stock.maxCount + sample.maxCount

                return slot, inventory.stacks[slot]
            end
        end
    else
        -- [todo] doesn't work with i/o inventories - it doesn't have to currently, but still.
        local size = InventoryElemental.getSize(inventory.name)

        for slot = 1, size do
            local stack = inventory.stacks[slot]

            if not stack then
                ---@type ItemStack
                stack = Utils.copy(sample)
                stack.count = 0
                inventory.stacks[slot] = stack

                local stock = inventory.stock[sample.name]

                if not stock then
                    stock = Utils.copy(sample)
                    stock.count = 0
                    stock.maxCount = 0
                    inventory.stock[sample.name] = stock
                end

                stock.maxCount = stock.maxCount + sample.maxCount

                return slot, inventory.stacks[slot]
            end
        end
    end
end

---@param name string
---@return string
local function removePrefix(name)
    local str = string.gsub(name, "minecraft:", "")
    return str
end

---@param from Inventory
---@param to Inventory
---@param item string
---@param transfer integer
local function toPrintTransferString(from, to, item, transfer)
    return string.format("%s > %s: %dx %s", removePrefix(from.name), removePrefix(to.name), transfer, removePrefix(item))
end

---@param from Inventory
---@param to Inventory
---@param item string
---@param total? integer
---@param rate? integer
---@param allowAllocate? boolean
---@return integer transferredTotal
function InventoryAdvanced.transferItem(from, to, item, total, rate, allowAllocate)
    rate = rate or getDefaultRate()

    if not total then
        if not from.stock[item] then
            return 0
        end

        total = from.stock[item].count
    end

    -- print(toPrintTransferString(from, to, item, total))
    allowAllocate = allowAllocate or InventoryBasic.isFurnace(to)

    local transferredTotal = 0
    local fromSlot, fromStack = nextFromStack(from.stacks, item)
    local fromStock = from.stock[item]
    local toSlot, toStack = nextToStack(to.stacks, item)

    if not toSlot and allowAllocate and fromStack then
        toSlot, toStack = allocateNextToStack(to, fromStack)
    end

    local toStock = to.stock[item]

    while transferredTotal < total and fromSlot and fromStack and toSlot and toStack do
        local space = toStack.maxCount - toStack.count
        local stock = fromStack.count
        local open = total - transferredTotal
        local transfer = math.min(space, open, rate, stock)
        local transferred = InventoryElemental.pushItems(from.name, to.name, fromSlot, transfer, toSlot)

        -- [todo] should we not remove the stack & stock completely once it is 0,
        -- so that the data state is the same as if we've read the inventory after transferring all?
        -- [todo] consider extracting stack/stock manipulation into a separate method
        fromStack.count = fromStack.count - transferred
        fromStock.count = fromStock.count - transferred
        toStack.count = toStack.count + transferred
        toStock.count = toStock.count + transferred

        -- [todo] consider moving the transfer rate timeout directly to pushItems()
        os.sleep(.5)

        transferredTotal = transferredTotal + transferred

        if transferred ~= transfer then
            print(toPrintTransferString(from, to, item, transferredTotal))

            return transferredTotal
        end

        fromSlot, fromStack = nextFromStack(from.stacks, item)
        toSlot, toStack = nextToStack(to.stacks, item)

        if not toSlot and allowAllocate and fromStack then
            toSlot, toStack = allocateNextToStack(to, fromStack)
        end
    end

    print(toPrintTransferString(from, to, item, transferredTotal))

    return transferredTotal
end

-- [todo] I'm wondering if i should move transferItem() to the complex layer.
---@param from Inventory
---@param to Inventory
---@param total table<string, integer>
---@param rate? integer
---@param allowAllocate? boolean
---@return table<string, integer> transferred
function InventoryAdvanced.transferItems(from, to, total, rate, allowAllocate)
    rate = rate or getDefaultRate()

    ---@type table<string, integer>
    local transferredTotal = {}

    for item, itemTotal in pairs(total) do
        local transferred = InventoryAdvanced.transferItem(from, to, item, itemTotal, rate, allowAllocate)

        if transferred > 0 then
            transferredTotal[item] = transferred
        end
    end

    return transferredTotal
end

---@param name string
---@param stacks? ItemStacks
-- [todo] slots
---@param slots? integer[]
---@return Inventory
function InventoryAdvanced.create(name, stacks, slots)
    stacks = stacks or InventoryBasic.getStacks(name)
    local stock = InventoryElemental.stacksToStock(stacks)

    ---@type Inventory
    local inventory = {name = name, stacks = stacks, stock = stock, slots = slots or {}}

    return inventory
end

---@param name string
---@param input Inventory
---@param output Inventory
---@param type InputOutputInventoryType?
---@param tagSlot? integer
---@return InputOutputInventory
function InventoryAdvanced.createInputOutput(name, input, output, type, tagSlot)
    ---@type InputOutputInventory
    -- [todo] tagSlot
    local inventory = {name = name, input = input, output = output, type = type or "io", tagSlot = tagSlot or -1}

    return inventory
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

---@param chest string
---@param stacks table<integer, ItemStack>
---@return Inventory
local function createMonoTypeInventory(chest, stacks)
    local first = Utils.first(stacks)
    ---@type ItemStack
    local template = {name = first.name, count = 0, displayName = first.displayName, maxCount = first.maxCount}

    for slot = 1, InventoryElemental.getSize(chest) do
        local stack = stacks[slot]

        if stack then
            stack.maxCount = stack.maxCount - 1
            stack.count = stack.count - 1
        else
            stacks[slot] = Utils.copy(template)
        end
    end

    return InventoryAdvanced.create(chest, stacks)
end

---@param chest string
---@param stacks table<integer, ItemStack>
---@return Inventory
local function createMultiTypeInventory(chest, stacks)
    for _, stack in pairs(stacks) do
        stack.maxCount = stack.maxCount - 1
        stack.count = stack.count - 1
    end

    return InventoryAdvanced.create(chest, stacks)
end

---@param chest string
---@param stacks table<integer, ItemStack>
---@return InputOutputInventory
function InventoryAdvanced.readStorage(chest, stacks)
    ---@type Inventory
    local inventory

    if isMonoTypeStacks(stacks) then
        inventory = createMonoTypeInventory(chest, stacks)
    else
        inventory = createMultiTypeInventory(chest, stacks)
    end

    return InventoryAdvanced.createInputOutput(chest, inventory, inventory, "storage")
end

---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return table<integer, ItemStack>, table<integer, ItemStack>
local function toInputOutputStacks(stacks, nameTagSlot)
    local inputStacks = {}
    local outputStacks = {}

    for slot, stack in pairs(stacks) do
        if slot ~= nameTagSlot then
            ---@type ItemStack
            local stack = Utils.clone(stack)
            stack.count = stack.count - 1
            stack.maxCount = stack.maxCount - 1

            if slot < nameTagSlot then
                inputStacks[slot] = stack
            elseif slot > nameTagSlot then
                outputStacks[slot] = stack
            end
        end
    end

    return inputStacks, outputStacks
end

---@param name string
---@param stacks? table<integer, ItemStack>
---@param nameTagSlot? integer
---@return InputOutputInventory
function InventoryAdvanced.readInputOutput_chest(name, stacks, nameTagSlot)
    if not stacks then
        stacks = InventoryBasic.getStacks(name)
    end

    if not nameTagSlot then
        nameTagSlot = InventoryBasic.findNameTag(name, {"I/O"}, stacks)

        if not nameTagSlot then
            error(("chest %s does not have an I/O name tag"):format(name))
        end
    end

    local inputStacks, outputStacks = toInputOutputStacks(stacks, nameTagSlot)
    local input = InventoryAdvanced.create(name, inputStacks)
    local output = InventoryAdvanced.create(name, outputStacks)

    return InventoryAdvanced.createInputOutput(name, input, output, "io")
end

---@param name string
---@return InputOutputInventory
function InventoryAdvanced.readFurnace(name)
    local stacks = InventoryBasic.getStacks(name)
    local inputStack = stacks[1]
    local fuelStack = stacks[2]
    local outputStack = stacks[3]

    ---@type ItemStack[]
    local inputStacks = {inputStack, fuelStack}

    ---@type ItemStack[]
    local outputStacks = {nil, nil, outputStack}

    local input = InventoryAdvanced.create(name, inputStacks)
    local output = InventoryAdvanced.create(name, outputStacks)

    return InventoryAdvanced.createInputOutput(name, input, output, "furnace")
end

---@param chest string
---@param ignoredSlots? table<integer>
---@return InputOutputInventory
function InventoryAdvanced.readFurnaceInput(chest, ignoredSlots)
    ignoredSlots = ignoredSlots or {}
    local stacks = InventoryBasic.getStacks(chest, true)

    local nameTag, nameTagSlot = Utils.find(stacks, function(item)
        return item.name == "minecraft:name_tag" and item.displayName == "Furnace: Input"
    end)

    if not nameTag or not nameTagSlot then
        error("failed to find furnace input name tag")
    end

    stacks[nameTagSlot] = nil

    for slot in pairs(ignoredSlots) do
        stacks[slot] = nil
    end

    local input = InventoryAdvanced.create(chest, {})
    local output = InventoryAdvanced.create(chest, stacks)

    return InventoryAdvanced.createInputOutput(chest, input, output, "furnace-input")
end

---@param chest string
---@param ignoredSlots? table<integer>
---@return InputOutputInventory
function InventoryAdvanced.readFurnaceOutput(chest, ignoredSlots)
    ignoredSlots = ignoredSlots or {}
    local stacks = InventoryBasic.getStacks(chest)

    for slot in pairs(ignoredSlots) do
        stacks[slot] = nil
    end

    local input = InventoryAdvanced.create(chest, stacks)
    local output = InventoryAdvanced.create(chest, {})

    return InventoryAdvanced.createInputOutput(chest, input, output, "furnace-output")
end

---@param chest string
---@param ignoredSlots? table<integer>
---@return InputOutputInventory
function InventoryAdvanced.readDrain(chest, ignoredSlots)
    ignoredSlots = ignoredSlots or {}
    local stacks = InventoryBasic.getStacks(chest, true)

    local nameTag, nameTagSlot = Utils.find(stacks, function(item)
        return item.name == "minecraft:name_tag" and item.displayName == "Drain"
    end)

    if not nameTag or not nameTagSlot then
        error("failed to find drain name tag")
    end

    stacks[nameTagSlot] = nil

    for slot in pairs(ignoredSlots) do
        stacks[slot] = nil
    end

    local input = InventoryAdvanced.create(chest, {})
    local output = InventoryAdvanced.create(chest, stacks)

    return InventoryAdvanced.createInputOutput(chest, input, output, "drain")
end

---@param chest string
---@param ignoredSlots? table<integer>
---@return InputOutputInventory
function InventoryAdvanced.readSilo(chest, ignoredSlots)
    ignoredSlots = ignoredSlots or {}
    local stacks = InventoryBasic.getStacks(chest)

    for slot in pairs(ignoredSlots) do
        stacks[slot] = nil
    end

    local input = InventoryAdvanced.create(chest, {})
    local output = InventoryAdvanced.create(chest, stacks)

    return InventoryAdvanced.createInputOutput(chest, input, output, "silo")
end

---@param name string
---@return InputOutputInventory
function InventoryAdvanced.readCrafterInventory(name)
    local stacks = InventoryBasic.getStacks(name)
    local tagSlot = InventoryBasic.findNameTag(name, {"Crafter"}, stacks)

    if not tagSlot then
        error("no Crafter tag found")
    end

    local inputSlotOffset = 3
    local outputSlotOffset = 6

    ---@param offset integer
    ---@param allStacks table<integer, ItemStack>
    local function toInventory(offset, allStacks)
        ---@type table<integer, ItemStack>
        local stacks = {}
        ---@type integer[]
        local slots = {}

        for i = 1, 9 do
            local line = math.ceil(i / 3)
            local offsetRight = (line - 1) * (9 - (offset + 3))
            local slot = i + (offset * line) + offsetRight

            table.insert(slots, slot)

            if allStacks[slot] then
                stacks[slot] = allStacks[slot]
            end
        end

        return InventoryAdvanced.create(name, stacks, slots)
    end

    local inputInventory = toInventory(inputSlotOffset, stacks)
    local outputInventory = toInventory(outputSlotOffset, stacks)

    return InventoryAdvanced.createInputOutput(name, inputInventory, outputInventory, "crafter", tagSlot)
end

---@param name string
---@return InputOutputInventory?
function InventoryAdvanced.readInputOutput(name)
    local baseType = baseTypeLookup[string.sub(name, 1, 15)]

    if not baseType then
        return nil
    end

    if baseType == "minecraft:furnace" then
        return InventoryAdvanced.readFurnace(name)
    elseif baseType == "minecraft:shulker_box" then
        local shulker = InventoryAdvanced.readStorage(name, InventoryBasic.getStacks(name))
        shulker.type = "shulker"

        return shulker
    else
        local stacks = InventoryBasic.getStacks(name)
        local tagNames = {"I/O", "Drain", "Silo", "Crafter", "Furnace: Input", "Furnace: Output"}
        local nameTagSlot, nameTagName = InventoryBasic.findNameTag(name, tagNames, stacks)

        if nameTagSlot and nameTagName then
            if nameTagName == "I/O" then
                return InventoryAdvanced.readInputOutput_chest(name, stacks, nameTagSlot)
            elseif nameTagName == "Drain" then
                return InventoryAdvanced.readDrain(name, {nameTagSlot})
            elseif nameTagName == "Silo" then
                return InventoryAdvanced.readSilo(name, {nameTagSlot})
            elseif nameTagName == "Crafter" then
                return InventoryAdvanced.readCrafterInventory(name)
            elseif nameTagName == "Furnace: Input" then
                return InventoryAdvanced.readFurnaceInput(name)
            elseif nameTagName == "Furnace: Output" then
                return InventoryAdvanced.readFurnaceOutput(name)
            end
        else
            return InventoryAdvanced.readStorage(name, stacks)
        end
    end
end

return InventoryAdvanced
