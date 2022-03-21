local Peripheral = require "world.peripheral"
local Side = require "elements.side"
local DetailedItemStack = require "world.detailed-item-stack"
local ItemStack = require "world.item-stack"

---@class Chest
---@field side integer
local Chest = {}

---@param side integer
---@return Chest
function Chest.new(side)
    side = Side.fromArg(side)
    ---@type Chest
    local instance = {side = side}
    setmetatable(instance, {__index = Chest})
    return instance
end

---@return ItemStack[]
function Chest:getItemList()
    local nativeList = Peripheral.call(self.side, "list")
    ---@type ItemStack[]
    local list = {}

    for slot, nativeItem in pairs(nativeList) do
        list[slot] = ItemStack.cast(nativeItem)
    end

    return list
end

---@return DetailedItemStack[]
function Chest:getDetailedItemList()
    local nativeList = Peripheral.call(self.side, "list")
    ---@type DetailedItemStack[]
    local list = {}

    for slot, _ in pairs(nativeList) do
        local nativeItem = Peripheral.call(self.side, "getItemDetail", slot);

        if (nativeItem == nil) then
            error("slot #" .. slot .. " unexpectedly empty")
        end

        list[slot] = DetailedItemStack.cast(nativeItem)
    end

    return list
end

function Chest:getFirstInputSlot()
    -- [todo] hardcoded
    return 19
end

function Chest:getLastInputSlot()
    -- [todo] hardcoded
    return 27
end

function Chest:getFirstOutputSlot()
    -- [todo] hardcoded
    return 1
end

function Chest:getLastOutputSlot()
    -- [todo] hardcoded
    return 18
end

---@param target integer
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function Chest:pushItems(target, fromSlot, limit, toSlot)
    return Peripheral.call(self.side, "pushItems", Side.getName(target), fromSlot, limit, toSlot)
end

---@param target integer
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function Chest:pullItems(target, fromSlot, limit, toSlot)
    return Peripheral.call(self.side, "pullItems", Side.getName(target), fromSlot, limit, toSlot)
end

---@return integer
function Chest:getSize()
    return Peripheral.call(self.side, "size")
end

return Chest
