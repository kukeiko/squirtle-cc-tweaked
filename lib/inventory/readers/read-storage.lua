local Utils = require "lib.tools.utils"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local Inventory = require "lib.inventory.inventory"

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
---@param stacks table<integer, ItemStack>
---@return Inventory
return function(name, stacks)
    ---@type table<integer, InventorySlot>
    local slots = {}
    ---@type InventorySlotTags
    local slotTags = {input = true, output = true, withdraw = true}
    ---@type table<string, integer>
    local items = {}

    if isMonoTypeStacks(stacks) then
        local first = Utils.first(stacks) --[[@as ItemStack]]
        items[first.name] = 0
        ---@type ItemStack
        local template = {name = first.name, count = 0, displayName = first.displayName, maxCount = first.maxCount}

        for index = 1, InventoryPeripheral.getSize(name) do
            ---@type InventorySlot
            local slot = {index = index, tags = slotTags, permanent = true}
            slots[index] = slot
            local stack = stacks[index]

            if stack then
                stack.maxCount = stack.maxCount - 1
                stack.count = stack.count - 1
                items[stack.name] = items[stack.name] + stack.count
            else
                stacks[index] = Utils.copy(template)
            end
        end
    else
        for index, stack in pairs(stacks) do
            slots[index] = {index = index, tags = slotTags, permanent = true}
            stack.maxCount = stack.maxCount - 1
            stack.count = stack.count - 1
            items[stack.name] = (items[stack.name] or 0) + stack.count
        end
    end

    return Inventory.create(name, "storage", stacks, slots, false, nil, items)
end
