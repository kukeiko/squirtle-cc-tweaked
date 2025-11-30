local Utils = require "lib.tools.utils"
local ItemStock = require "lib.inventory.item-stock"

local Inventory = {}

---@param name string
---@param type InventoryType
---@param stacks ItemStacks
---@param slots table<integer, InventorySlot>
---@param allowAllocate? boolean
---@param label? string
---@param items? table<string, integer>
---@return Inventory
function Inventory.create(name, type, stacks, slots, allowAllocate, label, items)
    ---@type Inventory
    local inventory = {
        name = name,
        type = type,
        stacks = stacks,
        allowAllocate = allowAllocate or false,
        slots = slots,
        label = label,
        items = items or {}
    }

    return inventory
end

---@param inventory Inventory
---@param item string
---@param tag InventorySlotTag
---@return integer
function Inventory.getItemCount(inventory, item, tag)
    if not inventory.items[item] then
        return 0
    end

    local count = 0

    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if stack and stack.name == item and slot.tags[tag] then
            count = count + stack.count
        end
    end

    return count
end

---@param inventory Inventory
---@param tag InventorySlotTag
---@return integer
function Inventory.getTotalItemCount(inventory, tag)
    local count = 0

    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if stack and slot.tags[tag] then
            count = count + stack.count
        end
    end

    return count
end

---@param inventory Inventory
---@param item string
---@param tag InventorySlotTag
---@return integer
function Inventory.getItemMaxCount(inventory, item, tag)
    if not inventory.items[item] then
        return 0
    end

    local maxCount = 0

    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if stack and stack.name == item and slot.tags[tag] then
            maxCount = maxCount + stack.maxCount
        end
    end

    return maxCount
end

---@param inventory Inventory
---@param item string
---@param tag InventorySlotTag
---@return integer
function Inventory.getItemOpenCount(inventory, item, tag)
    if not inventory.items[item] then
        return 0
    end

    local count = Inventory.getItemCount(inventory, item, tag)
    local maxCount = Inventory.getItemMaxCount(inventory, item, tag)

    return maxCount - count
end

---@param inventory Inventory
---@param tag InventorySlotTag
---@return integer
function Inventory.getSlotCount(inventory, tag)
    local count = 0

    for _, slot in pairs(inventory.slots) do
        if slot.tags[tag] == true then
            count = count + 1
        end
    end

    return count
end

---@param inventory Inventory
---@param tag? InventorySlotTag
---@return ItemStock
function Inventory.getStock(inventory, tag)
    ---@type ItemStock
    local stock = {}

    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if stack and (not tag or slot.tags[tag]) then
            stock[stack.name] = (stock[stack.name] or 0) + stack.count
        end
    end

    return stock
end

---@param inventory Inventory
---@param tag InventorySlotTag
---@return ItemStock
function Inventory.getMaxStock(inventory, tag)
    ---@type ItemStock
    local stock = {}

    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if stack and slot.tags[tag] then
            stock[stack.name] = (stock[stack.name] or 0) + stack.maxCount
        end
    end

    return stock
end

---@param inventory Inventory
---@param tag InventorySlotTag
---@return ItemStock
function Inventory.getOpenStock(inventory, tag)
    ---@type ItemStock
    local stock = {}

    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if stack and slot.tags[tag] then
            stock[stack.name] = (stock[stack.name] or 0) + (stack.maxCount - stack.count)
        end
    end

    return stock
end

---@param slot InventorySlot
---@param stack? ItemStack
---@param tag InventorySlotTag
---@param item string
---@return boolean
function Inventory.slotCanProvideItem(slot, stack, tag, item)
    return stack ~= nil and slot.tags[tag] and stack.count > 0 and stack.name == item
end

---@param slot InventorySlot
---@param stack? ItemStack
---@param tag InventorySlotTag
---@param allowAllocate boolean
---@param item string
---@return boolean
function Inventory.slotCanTakeItem(slot, stack, tag, allowAllocate, item)
    return slot.tags[tag] and ((stack and stack.name == item and stack.count < stack.maxCount) or (not stack and allowAllocate))
end

---@param inventory Inventory
---@param item string
---@param tag InventorySlotTag
---@return boolean
function Inventory.canProvideItem(inventory, item, tag)
    if not inventory.items[item] then
        return false
    end

    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if Inventory.slotCanProvideItem(slot, stack, tag, item) then
            return true
        end
    end

    return false
end

---@param inventory Inventory
---@param item string
---@param tag InventorySlotTag
---@return boolean
function Inventory.canTakeItem(inventory, item, tag)
    if not inventory.allowAllocate and not inventory.items[item] then
        return false
    end

    for index, slot in pairs(inventory.slots) do
        if Inventory.slotCanTakeItem(slot, inventory.stacks[index], tag, inventory.allowAllocate, item) then
            return true
        end
    end

    return false
end

---@param inventory Inventory
---@param item string
---@param tag InventorySlotTag
---@return InventorySlot? slot, integer? available
function Inventory.nextFromSlot(inventory, item, tag)
    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if Inventory.slotCanProvideItem(slot, stack, tag, item) then
            return slot, stack and stack.count or nil
        end
    end
end

---@param inventory Inventory
---@param item string
---@param tag InventorySlotTag
---@return InventorySlot? slot, integer? open
function Inventory.nextToSlot(inventory, item, tag)
    for index, slot in pairs(inventory.slots) do
        if Inventory.slotCanTakeItem(slot, inventory.stacks[index], tag, inventory.allowAllocate, item) then
            local stack = inventory.stacks[index]

            return slot, stack and (stack.maxCount - stack.count) or nil
        end
    end
end

---@param inventory Inventory
---@param slotIndex integer
---@param item string
---@param quantity integer
---@param maxCount integer
---@return integer
function Inventory.addItem(inventory, slotIndex, item, quantity, maxCount)
    local stack = inventory.stacks[slotIndex]

    if not inventory.stacks[slotIndex] then
        inventory.stacks[slotIndex] = {name = item, count = 0, maxCount = maxCount}
        stack = inventory.stacks[slotIndex]
    end

    local transferred = math.min(quantity, stack.maxCount - stack.count)
    stack.count = stack.count + transferred
    inventory.items[item] = (inventory.items[item] or 0) + quantity

    return transferred
end

---@param inventory Inventory
---@param slotIndex integer
---@param item string
---@param quantity integer
function Inventory.removeItem(inventory, slotIndex, item, quantity)
    local stack = inventory.stacks[slotIndex]
    local slot = inventory.slots[slotIndex]

    inventory.items[item] = inventory.items[item] - quantity
    stack.count = stack.count - quantity

    if stack.count == 0 and not slot.permanent then
        inventory.stacks[slot.index] = nil
    end
end

---@param inventory Inventory
---@param item string
---@param quantity integer
---@param tag InventorySlotTag
---@param itemDetails ItemDetails
---@return integer
local function fakeMoveItem(inventory, item, quantity, tag, itemDetails)
    local details = itemDetails[item] or error(string.format("item details missing for %s", item))
    local open = quantity

    while open > 0 do
        local nextSlot = Inventory.nextToSlot(inventory, item, tag)

        if not nextSlot then
            break
        end

        local moved = Inventory.addItem(inventory, nextSlot.index, item, open, details.maxCount)
        open = open - moved
    end

    return quantity - open
end

---@param inventory Inventory
---@param stock ItemStock
---@param tag InventorySlotTag
---@param itemDetails ItemDetails
---@return ItemStock sliced, ItemStock open
function Inventory.sliceStock(inventory, stock, tag, itemDetails)
    inventory = Utils.clone(inventory)
    local open = Utils.copy(stock)

    -- first we fill up existing stacks
    for item in pairs(inventory.items) do
        if open[item] then
            open[item] = open[item] - fakeMoveItem(inventory, item, open[item], tag, itemDetails)

            if open[item] == 0 then
                open[item] = nil
            end
        end
    end

    -- then we insert new items
    for _, item in pairs(Utils.getKeys(open)) do
        open[item] = open[item] - fakeMoveItem(inventory, item, open[item], tag, itemDetails)

        if open[item] == 0 then
            open[item] = nil
        end
    end

    return ItemStock.subtract(stock, open), open
end

return Inventory
