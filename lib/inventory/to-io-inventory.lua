local copy = require "utils.copy"
local getStacks = require "inventory.get-stacks"
local stacksToStock = require "inventory.stacks-to-stock"
local findNameTag = require "inventory.find-name-tag"
local Inventory = require "inventory.inventory"
local InputOutputInventory = require "inventory.input-output-inventory"

---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return table<integer, ItemStack>, table<integer, ItemStack>
local function toInputOutputStacks(stacks, nameTagSlot)
    local inputStacks = {}
    local outputStacks = {}

    for slot, stack in pairs(stacks) do
        if slot ~= nameTagSlot then
            ---@type ItemStack
            local stack = copy(stack)
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
return function(name, stacks, nameTagSlot)
    if not stacks then
        stacks = getStacks(name)
    end

    if not nameTagSlot then
        nameTagSlot = findNameTag(name, {"I/O"}, stacks)

        if not nameTagSlot then
            error(("chest %s does not have an I/O name tag"):format(name))
        end
    end

    local inputStacks, outputStacks = toInputOutputStacks(stacks, nameTagSlot)
    local input = Inventory.create(name, inputStacks)
    local output = Inventory.create(name, outputStacks)

    return InputOutputInventory.create(name, input, output, "io")
end
