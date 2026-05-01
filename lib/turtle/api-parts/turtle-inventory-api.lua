local Utils = require "lib.tools.utils"
local ItemStock = require "lib.inventory.item-stock"
local ItemApi = require "lib.inventory.item-api"
local getIoSlots = require "lib.turtle.functions.get-io-slots"

---@class TurtleInventoryApi
local TurtleInventoryApi = {}

---@return integer
function TurtleInventoryApi.size()
    return 16
end

---@param slot? integer
---@return integer
function TurtleInventoryApi.getItemCount(slot)
    return turtle.getItemCount(slot)
end

---@param slot? integer
---@return integer
function TurtleInventoryApi.getItemSpace(slot)
    return turtle.getItemSpace(slot)
end

---@return integer
function TurtleInventoryApi.getSelectedSlot()
    return turtle.getSelectedSlot()
end

---@return integer[]
function TurtleInventoryApi.getIoSlots()
    return getIoSlots()
end

---@return integer[]
function TurtleInventoryApi.getNonIoSlots()
    ---@type integer[]
    local nonIoSlots = {}
    local ioSlots = getIoSlots()

    for slot = 1, TurtleInventoryApi.size() do
        if not Utils.contains(ioSlots, slot) then
            table.insert(nonIoSlots, slot)
        end
    end

    return nonIoSlots
end

---@param TurtleApi TurtleApi
---@param slot integer
---@return boolean
function TurtleInventoryApi.select(TurtleApi, slot)
    if TurtleApi.isSimulating() then
        return true
    end

    return turtle.select(slot)
end

---@param slot? integer
---@param detailed? boolean
---@return ItemStack?
function TurtleInventoryApi.getStack(slot, detailed)
    ---@type ItemStack?
    local itemStack = turtle.getItemDetail(slot or TurtleInventoryApi.getSelectedSlot(), detailed)

    if itemStack and ItemApi.isCustomUnstackable(itemStack.name) then
        itemStack.maxCount = 1
    end

    return itemStack
end

---@param detailed? boolean
---@param excludeIo? boolean
---@return ItemStack[]
function TurtleInventoryApi.getStacks(detailed, excludeIo)
    local ioSlots = getIoSlots()
    local stacks = {}

    for slot = 1, TurtleInventoryApi.size() do
        if not excludeIo or not Utils.contains(ioSlots, slot) then
            local item = TurtleInventoryApi.getStack(slot, detailed)

            if item then
                stacks[slot] = item
            end
        end
    end

    return stacks
end

---@param predicate string|function<boolean, ItemStack>
---@return integer
function TurtleInventoryApi.getItemStock(predicate)
    if type(predicate) == "string" then
        local name = predicate

        ---@param stack ItemStack
        ---@type function<boolean, ItemStack>
        predicate = function(stack)
            return stack.name == name
        end
    end

    local stock = 0

    for _, stack in pairs(TurtleInventoryApi.getStacks()) do
        if predicate(stack) then
            stock = stock + stack.count
        end
    end

    return stock
end

---@param TurtleApi TurtleApi
---@param includeShulkers? boolean
---@param excludeIo? boolean
---@return table<string, integer>
function TurtleInventoryApi.getStock(TurtleApi, includeShulkers, excludeIo)
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(TurtleInventoryApi.getStacks(false, excludeIo)) do
        stock[stack.name] = (stock[stack.name] or 0) + stack.count
    end

    if includeShulkers then
        stock = ItemStock.merge({stock, TurtleApi.getShulkerStock()})
    end

    return stock
end

---@param slot integer
---@param quantity? integer
---@return boolean, integer
function TurtleInventoryApi.transferTo(slot, quantity)
    local currentQuantity = TurtleInventoryApi.getItemCount(slot)
    local success = turtle.transferTo(slot, quantity)

    return success, currentQuantity - TurtleInventoryApi.getItemCount(slot)
end

---@param TurtleApi TurtleApi
---@param slot integer
---@return boolean
function TurtleInventoryApi.selectIfNotEmpty(TurtleApi, slot)
    if TurtleInventoryApi.getItemCount(slot) > 0 then
        return TurtleInventoryApi.select(TurtleApi, slot)
    else
        return false
    end
end

---@param TurtleApi TurtleApi
---@param startAt? number
---@return integer
function TurtleInventoryApi.selectEmpty(TurtleApi, startAt)
    startAt = startAt or TurtleInventoryApi.getSelectedSlot()

    for i = 0, TurtleInventoryApi.size() - 1 do
        local slot = startAt + i

        if slot > TurtleInventoryApi.size() then
            slot = slot - TurtleInventoryApi.size()
        end

        if TurtleInventoryApi.getItemCount(slot) == 0 then
            TurtleInventoryApi.select(TurtleApi, slot)

            return slot
        end
    end

    error("no empty slot available")
end

---@param TurtleApi TurtleApi
---@return integer
function TurtleInventoryApi.selectFirstEmpty(TurtleApi)
    return TurtleInventoryApi.selectEmpty(TurtleApi, 1)
end

---@param startAt? number
function TurtleInventoryApi.firstEmptySlot(startAt)
    -- [todo] ❌ this startAt logic works a bit differently to "TurtleInventoryApi.selectEmpty()" as it does not wrap around
    startAt = startAt or 1

    for slot = startAt, TurtleInventoryApi.size() do
        if TurtleInventoryApi.getItemCount(slot) == 0 then
            return slot
        end
    end

    return nil
end

---@return integer
function TurtleInventoryApi.numEmptySlots()
    local numEmpty = 0

    for slot = 1, TurtleInventoryApi.size() do
        if TurtleInventoryApi.getItemCount(slot) == 0 then
            numEmpty = numEmpty + 1
        end
    end

    return numEmpty
end

---@return boolean
function TurtleInventoryApi.isFull()
    for slot = 1, TurtleInventoryApi.size() do
        if TurtleInventoryApi.getItemCount(slot) == 0 then
            return false
        end
    end

    return true
end

---@return boolean
function TurtleInventoryApi.isEmpty()
    for slot = 1, TurtleInventoryApi.size() do
        if TurtleInventoryApi.getItemCount(slot) > 0 then
            return false
        end
    end

    return true
end

---@param name string
---@param nbt? string
---@param slots? integer[]
---@return integer?
function TurtleInventoryApi.find(name, nbt, slots)
    for slot = 1, TurtleInventoryApi.size() do
        if not slots or Utils.contains(slots, slot) then
            local item = TurtleInventoryApi.getStack(slot)

            if item and item.name == name and (nbt == nil or item.nbt == nbt) then
                return slot
            end
        end
    end
end

---@param item string
---@param minCount? integer
---@return boolean
function TurtleInventoryApi.has(item, minCount)
    if type(minCount) == "number" then
        return TurtleInventoryApi.getItemStock(item) >= minCount
    else
        for slot = 1, TurtleInventoryApi.size() do
            local stack = TurtleInventoryApi.getStack(slot)

            if stack and stack.name == item then
                return true
            end
        end

        return false
    end
end

---Condenses the inventory by stacking matching items.
---@param TurtleApi TurtleApi
function TurtleInventoryApi.condense(TurtleApi)
    if TurtleApi.isSimulating() then
        return nil
    end

    repeat
        local didTransfer = false

        for slot = TurtleInventoryApi.size(), 1, -1 do
            local item = TurtleInventoryApi.getStack(slot)

            if item then
                for targetSlot = 1, slot - 1 do
                    local candidate = TurtleInventoryApi.getStack(targetSlot, true)

                    if candidate and candidate.name == item.name and candidate.count < candidate.maxCount then
                        TurtleInventoryApi.select(TurtleApi, slot)
                        TurtleInventoryApi.transferTo(targetSlot)
                        didTransfer = true

                        if TurtleInventoryApi.getItemCount(slot) == 0 then
                            break
                        end
                    elseif not candidate then
                        TurtleInventoryApi.select(TurtleApi, slot)
                        TurtleInventoryApi.transferTo(targetSlot)
                        didTransfer = true
                        break
                    end
                end
            end
        end
    until not didTransfer
end

return TurtleInventoryApi
