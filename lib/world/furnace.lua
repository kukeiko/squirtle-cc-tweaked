local Side = require "elements.side"
local Peripheral = require "world.peripheral"
local Furnace = {}

local inputSlot = 1
local fuelSlot = 2
local outputSlot = 3

function Furnace.findSide()
    return Peripheral.findSide("minecraft:furnace")
end

---@param side integer|string
---@return ItemStack
function Furnace.getInputStack(side)
    return Peripheral.call(side, "getItemDetail", inputSlot)
end

function Furnace.getMissingInputCount(side)
    local stack = Furnace.getInputStack(side)

    if not stack then
        return 64
    end

    return stack.maxCount - stack.count
end

---@param side integer|string
---@return ItemStack
function Furnace.getFuelStack(side)
    return Peripheral.call(side, "getItemDetail", fuelSlot)
end

function Furnace.getMissingFuelCount(side)
    local stack = Furnace.getFuelStack(side)

    if not stack then
        return 64
    end

    return stack.maxCount - stack.count
end

---@param side integer|string
---@return ItemStack
function Furnace.getOutputStack(side)
    return Peripheral.call(side, "getItemDetail", outputSlot)
end

---@param from integer|string
---@param to integer|string
---@param limit? integer
---@param slot? integer
---@return integer transferred
function Furnace.pushOutput(from, to, limit, slot)
    return Peripheral.call(from, "pushItems", Side.getName(to), outputSlot, limit, slot)
end

---@param to integer|string
---@param from integer|string
---@param limit? integer
---@param slot? integer
---@return integer transferred
function Furnace.pullFuel(to, from, slot, limit)
    return Peripheral.call(to, "pullItems", Side.getName(from), slot, limit, fuelSlot)
end

function Furnace.getFuelCount(side)
    local fuelStack = Furnace.getFuelStack(side)

    if not fuelStack then
        return 0
    end

    return fuelStack.count
end

---@param to integer|string
---@param from integer|string
---@param limit? integer
---@param slot? integer
---@return integer transferred
function Furnace.pullInput(to, from, slot, limit)
    return Peripheral.call(to, "pullItems", Side.getName(from), slot, limit, inputSlot)
end

---@param side integer|string
---@param limit? integer
---@return integer transferred
function Furnace.pullFuelFromInput(side, limit)
    return Peripheral.call(side, "pullItems", Side.getName(side), inputSlot, limit, fuelSlot)
end

---@param side integer|string
---@param limit? integer
---@return integer transferred
function Furnace.pullFuelFromOutput(side, limit)
    return Peripheral.call(side, "pullItems", Side.getName(side), outputSlot, limit, fuelSlot)
end

return Furnace
