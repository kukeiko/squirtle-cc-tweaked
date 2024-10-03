local Utils = require "lib.common.utils"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local constructInventory = require "lib.inventory.construct-inventory"

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
    ---@type table<string, true>
    local items = {}

    if isMonoTypeStacks(stacks) then
        local first = Utils.first(stacks)
        items[first.name] = true
        ---@type ItemStack
        local template = {name = first.name, count = 0, displayName = first.displayName, maxCount = first.maxCount}

        for index = 1, InventoryPeripheral.getSize(name) do
            ---@type InventorySlot
            -- [todo] find references on "tags" doesn't work? (when using it on the type in inventory-elemental.lua file)
            local slot = {index = index, tags = {input = true, output = true, withdraw = true}, permanent = true}
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
            slots[index] = {index = index, tags = {input = true, output = true, withdraw = true}, permanent = true}
            stack.maxCount = stack.maxCount - 1
            stack.count = stack.count - 1
            items[stack.name] = true
        end
    end

    return constructInventory(name, "storage", stacks, slots, false, nil, items)
end
