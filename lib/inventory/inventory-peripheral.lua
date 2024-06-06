---@class InventoryPeripheral
local InventoryPeripheral = {}

---@type table<string, integer>
local itemMaxCounts = {}

---@type table<string, string>
local itemDisplayNames = {}

-- [todo] not the best place, but works for now
function InventoryPeripheral.getItemDisplayNames()
    return itemDisplayNames
end

---@param item string
---@param chest string
---@param slot integer
local function getItemMaxCount(item, chest, slot)
    if not itemMaxCounts[item] then
        ---@type ItemStack|nil
        local detailedStack = InventoryPeripheral.getStack(chest, slot)

        if detailedStack then
            itemMaxCounts[item] = detailedStack.maxCount
            itemDisplayNames[item] = detailedStack.displayName
        end
    end

    return itemMaxCounts[item]
end

---@param inventory string
---@return integer
function InventoryPeripheral.getSize(inventory)
    return peripheral.call(inventory, "size")
end

---@param side string
---@param slot integer
---@return ItemStack
function InventoryPeripheral.getStack(side, slot)
    return peripheral.call(side, "getItemDetail", slot)
end

---@param name string
---@param detailed? boolean
---@return ItemStacks
function InventoryPeripheral.getStacks(name, detailed)
    if not detailed then
        ---@type ItemStacks
        local stacks = peripheral.call(name, "list")

        for slot, stack in pairs(stacks) do
            stack.maxCount = getItemMaxCount(stack.name, name, slot)
        end

        return stacks
    else
        local stacks = peripheral.call(name, "list")
        ---@type ItemStacks
        local detailedStacks = {}

        for slot, _ in pairs(stacks) do
            detailedStacks[slot] = InventoryPeripheral.getStack(name, slot)
        end

        return detailedStacks
    end
end

---@param from string
---@param to string
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function InventoryPeripheral.pushItems(from, to, fromSlot, limit, toSlot)
    os.sleep(.25)
    return peripheral.call(from, "pushItems", to, fromSlot, limit, toSlot)
end

---@param inventory string
---@param fromSlot integer
---@param toSlot? integer
---@param quantity? integer
---@return integer
function InventoryPeripheral.move(inventory, fromSlot, toSlot, quantity)
    os.sleep(.5) -- [note] exists on purpose, as I don't want turtles to move items too quickly in suckSlot()
    return InventoryPeripheral.pushItems(inventory, inventory, fromSlot, quantity, toSlot)
end

return InventoryPeripheral
