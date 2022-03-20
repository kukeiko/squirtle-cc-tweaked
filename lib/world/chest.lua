local Peripheral = require "kiwi.core.peripheral"
local KiwiSide = require "kiwi.core.side"
local KiwiDetailedItemStack = require "kiwi.core.detailed-item-stack"
local KiwiItemStack = require "kiwi.core.item-stack"

---@class KiwiChest
---@field side integer
local KiwiChest = {}

---@param side integer
---@return KiwiChest
function KiwiChest.new(side)
    side = KiwiSide.fromArg(side)
    ---@type KiwiChest
    local instance = {side = side}
    setmetatable(instance, {__index = KiwiChest})
    return instance
end

---@return KiwiItemStack[]
function KiwiChest:getItemList()
    local nativeList = Peripheral.call(self.side, "list")
    ---@type KiwiItemStack[]
    local list = {}

    for slot, nativeItem in pairs(nativeList) do
        list[slot] = KiwiItemStack.cast(nativeItem)
    end

    return list
end

---@return KiwiDetailedItemStack[]
function KiwiChest:getDetailedItemList()
    local nativeList = Peripheral.call(self.side, "list")
    ---@type KiwiDetailedItemStack[]
    local list = {}

    for slot, _ in pairs(nativeList) do
        local nativeItem = Peripheral.call(self.side, "getItemDetail", slot);

        if (nativeItem == nil) then
            error("slot #" .. slot .. " unexpectedly empty")
        end

        list[slot] = KiwiDetailedItemStack.cast(nativeItem)
    end

    return list
end

function KiwiChest:getFirstInputSlot()
    -- [todo] hardcoded
    return 19
end

function KiwiChest:getLastInputSlot()
    -- [todo] hardcoded
    return 27
end

function KiwiChest:getFirstOutputSlot()
    -- [todo] hardcoded
    return 1
end

function KiwiChest:getLastOutputSlot()
    -- [todo] hardcoded
    return 18
end

---@param target integer
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function KiwiChest:pushItems(target, fromSlot, limit, toSlot)
    return Peripheral.call(self.side, "pushItems", KiwiSide.getName(target), fromSlot, limit, toSlot)
end

---@param target integer
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function KiwiChest:pullItems(target, fromSlot, limit, toSlot)
    return Peripheral.call(self.side, "pullItems", KiwiSide.getName(target), fromSlot, limit, toSlot)
end

---@return integer
function KiwiChest:getSize()
    return Peripheral.call(self.side, "size")
end

return KiwiChest
