local Utils = require "lib.common.utils"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local Inventory = require "lib.inventory.inventory"

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
            -- [todo] remove clone once cc:tweaked is updated
            slots[index] = {index = index, tags = Utils.clone(inputTags)}
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
