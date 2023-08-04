local Utils = require "utils"
local Inventory = require "inventory.inventory"
local InputOutputInventory = require "inventory.input-output-inventory"
local getSize = require "inventory.get-size"

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

    for slot = 1, getSize(chest) do
        local stack = stacks[slot]

        if stack then
            stack.maxCount = stack.maxCount - 1
            stack.count = stack.count - 1
        else
            stacks[slot] = Utils.copy(template)
        end
    end

    return Inventory.create(chest, stacks)
end

---@param chest string
---@param stacks table<integer, ItemStack>
---@return Inventory
local function createMultiTypeInventory(chest, stacks)
    for _, stack in pairs(stacks) do
        stack.maxCount = stack.maxCount - 1
        stack.count = stack.count - 1
    end

    return Inventory.create(chest, stacks)
end

---@param chest string
---@param stacks table<integer, ItemStack>
---@return InputOutputInventory
return function(chest, stacks)
    ---@type Inventory
    local inventory

    if isMonoTypeStacks(stacks) then
        inventory = createMonoTypeInventory(chest, stacks)
    else
        inventory = createMultiTypeInventory(chest, stacks)

    end

    return InputOutputInventory.create(chest, inventory, inventory, "storage")
end
