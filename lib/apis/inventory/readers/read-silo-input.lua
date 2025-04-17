local Utils = require "lib.tools.utils"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local Inventory = require "lib.models.inventory"

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
return function(name, stacks, nameTagSlot)
    ---@type table<integer, InventorySlot>
    local slots = {}
    local first = Utils.first(stacks)
    ---@type ItemStack?
    local template

    if first then
        template = {name = first.name, count = 0, displayName = first.displayName, maxCount = first.maxCount}
    end

    ---@type InventorySlotTags
    local inputTags = {input = true}
    ---@type ItemStock
    local items = {}

    for index = 1, InventoryPeripheral.getSize(name) do
        if index == nameTagSlot then
            slots[index] = {index = index, tags = {nameTag = true}}
        elseif template then
            slots[index] = {index = index, tags = inputTags}
            local stack = stacks[index]

            if stack then
                stack.maxCount = stack.maxCount - 1
                stack.count = stack.count - 1
                items[stack.name] = (items[stack.name] or 0) + stack.count
            else
                stacks[index] = Utils.copy(template)
            end
        end
    end

    return Inventory.create(name, "silo:input", stacks, slots, false, nil, items)
end
