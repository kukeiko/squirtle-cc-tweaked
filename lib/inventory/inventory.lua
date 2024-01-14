local Utils = require "utils"
local InputOutputInventory = require "inventory.input-output-inventory"
local InventoryElemental = require "inventory.inventory-elemental"
local InventoryComplex = require "inventory.inventory-complex"



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

---@class InventoryApi:InventoryComplex
local Inventory = {}
setmetatable(Inventory, {__index = InventoryComplex})

-- [todo] confusing: InputOutputInventory.create(...) works quite differently.
-- solution: rename methods - maybe "readInputOutput()" to identify input/output inventories via nametag slot,
-- and have "createInputOutput()" just be a constructor (like what InputOutputInventory.create() already is)
---@param name string
---@param stacks? table<integer, ItemStack>
---@param nameTagSlot? integer
---@return InputOutputInventory
function Inventory.createInputOutput_old(name, stacks, nameTagSlot)
    if not stacks then
        stacks = Inventory.getStacks(name)
    end

    if not nameTagSlot then
        nameTagSlot = Inventory.findNameTag(name, {"I/O"}, stacks)

        if not nameTagSlot then
            error(("chest %s does not have an I/O name tag"):format(name))
        end
    end

    local inputStacks, outputStacks = toInputOutputStacks(stacks, nameTagSlot)
    local input = Inventory.create(name, inputStacks)
    local output = Inventory.create(name, outputStacks)

    return InputOutputInventory.create(name, input, output, "io")
end

---@param name string
---@return ItemStock
function Inventory.getStock(name)
    return InventoryElemental.stacksToStock(Inventory.getStacks(name))
end

---@param name string
---@return ItemStock
function Inventory.getInputStock(name)
    return InventoryElemental.stacksToStock(Inventory.getInputStacks(name, true))
end

---@param name string
function Inventory.countItems(name)
    local stock = InventoryElemental.stacksToStock(Inventory.getStacks(name))
    local count = 0

    for _, itemStock in pairs(stock) do
        count = count + itemStock.count
    end

    return count
end

---@param side string
---@param predicate string|function<boolean, ItemStack>
---@return integer
function Inventory.getItemStock(side, predicate)
    if type(predicate) == "string" then
        local name = predicate

        ---@param stack ItemStack
        ---@type function<boolean, ItemStack>
        predicate = function(stack)
            return stack.name == name
        end
    end

    local stock = 0

    for _, stack in pairs(Inventory.getStacks(side)) do
        if predicate(stack) then
            stock = stock + stack.count
        end
    end

    return stock
end

---@param name string
---@param detailed? boolean
---@return ItemStacks
function Inventory.getInputStacks(name, detailed)
    ---@type ItemStacks
    local inputStacks = {}
    local stacks = Inventory.getStacks(name)
    local nameTagSlot = Inventory.findNameTag(name, {"I/O"}, stacks)

    if nameTagSlot then
        for slot, stack in pairs(stacks) do
            if slot < nameTagSlot then
                inputStacks[slot] = stack
            end
        end
    elseif Inventory.getSize(name) > 27 then -- 2+ wide - assumed to be a storage chest (=> input)
        inputStacks = stacks
    end

    if detailed then
        for slot in pairs(inputStacks) do
            inputStacks[slot] = InventoryElemental.getStack(name, slot)
        end
    end

    return inputStacks
end

-- [todo] copied to InventoryBasic
---@param name string
---@param tagNames table<string>
---@param stacks table<integer, ItemStack>
---@return integer? slot, string? name
function Inventory.findNameTag(name, tagNames, stacks)
    for slot, stack in pairs(stacks) do
        if stack.name == "minecraft:name_tag" then
            local stack = InventoryElemental.getStack(name, slot)

            if Utils.indexOf(tagNames, stack.displayName) > 0 then
                return slot, stack.displayName
            end
        end
    end
end

---@param name string
---@param detailed? boolean
function Inventory.getOutputStacks(name, detailed)
    ---@type table<integer, ItemStack>
    local outputStacks = {}
    local stacks = Inventory.getStacks(name)
    local nameTagSlot = Inventory.findNameTag(name, {"I/O"}, stacks)

    if nameTagSlot then
        for slot, stack in pairs(stacks) do
            if slot > nameTagSlot then
                outputStacks[slot] = stack
            end
        end
    elseif Inventory.getSize(name) == 27 then -- 1 wide - assumed to be a autofarm chest (=> output)
        outputStacks = stacks
    end

    if detailed then
        for slot in pairs(outputStacks) do
            outputStacks[slot] = InventoryElemental.getStack(name, slot)
        end
    end

    return outputStacks
end

---@param name string
---@return table<string, integer>
function Inventory.getOutputMissingStock(name)
    ---@type table<string, integer>
    local missingStock = {}
    local stock = InventoryElemental.stacksToStock(Inventory.getOutputStacks(name))

    for item, stack in pairs(stock) do
        missingStock[item] = stack.maxCount - stack.count
    end

    return missingStock
end

return Inventory
