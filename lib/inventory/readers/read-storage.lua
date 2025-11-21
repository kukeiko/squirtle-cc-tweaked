local Utils = require "lib.tools.utils"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local Inventory = require "lib.inventory.inventory"

---@param name string
---@param stacks table<integer, ItemStack>
---@param autoStorage? boolean
---@return Inventory
return function(name, stacks, autoStorage)
    ---@type table<integer, InventorySlot>
    local slots = {}
    ---@type InventorySlotTags
    local slotTags = {input = true, output = true, withdraw = true}
    ---@type table<string, integer>
    local items = {}

    if autoStorage then
        for index = 1, InventoryPeripheral.getSize(name) do
            ---@type InventorySlot
            local slot = {index = index, tags = slotTags}
            slots[index] = slot
            local stack = stacks[index]

            if stack then
                stacks[index] = stack
                items[stack.name] = (items[stack.name] or 0) + stack.count
            end
        end

        return Inventory.create(name, "storage", stacks, slots, true, nil, items)
    end

    ---@type ItemStack?
    local templateStack

    for index = 1, InventoryPeripheral.getSize(name) do
        ---@type InventorySlot
        local slot = {index = index, tags = slotTags, permanent = true}
        slots[index] = slot
        local stack = stacks[index]

        if stack then
            if not templateStack or stack.name ~= templateStack.name then
                templateStack = Utils.copy(stack)
                templateStack.count = 0
                stack.count = stack.count - 1
                stack.maxCount = stack.maxCount - 1
            end

            stacks[index] = stack
            items[stack.name] = (items[stack.name] or 0) + stack.count
        elseif templateStack then
            stacks[index] = Utils.copy(templateStack)
        end
    end

    return Inventory.create(name, "storage", stacks, slots, false, nil, items)
end
