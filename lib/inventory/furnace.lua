local Furnace = {}

local inputSlot = 1
local fuelSlot = 2
local outputSlot = 3

---@param furnace string
---@return ItemStack
function Furnace.getInputStack(furnace)
    return peripheral.call(furnace, "getItemDetail", inputSlot)
end

---@param furnace string
function Furnace.getMissingInputCount(furnace)
    local stack = Furnace.getInputStack(furnace)

    if not stack then
        return 64
    end

    return stack.maxCount - stack.count
end

---@param furnace string
---@return ItemStack
function Furnace.getFuelStack(furnace)
    return peripheral.call(furnace, "getItemDetail", fuelSlot)
end

---@param furnace string
---@return integer
function Furnace.getMissingFuelCount(furnace)
    local stack = Furnace.getFuelStack(furnace)

    if not stack then
        return 64
    end

    return stack.maxCount - stack.count
end

---@param furnace string
---@return ItemStack
function Furnace.getOutputStack(furnace)
    return peripheral.call(furnace, "getItemDetail", outputSlot)
end

---@param furnace string
---@param to string
---@param limit? integer
---@param slot? integer
---@return integer transferred
function Furnace.pushOutput(furnace, to, limit, slot)
    return peripheral.call(furnace, "pushItems", to, outputSlot, limit, slot)
end

---@param furnace string
---@param from string
---@param limit? integer
---@param slot? integer
---@return integer transferred
function Furnace.pullFuel(furnace, from, slot, limit)
    return peripheral.call(furnace, "pullItems", from, slot, limit, fuelSlot)
end

function Furnace.getFuelCount(side)
    local fuelStack = Furnace.getFuelStack(side)

    if not fuelStack then
        return 0
    end

    return fuelStack.count
end

---@param furnace string
---@param from string
---@param limit? integer
---@param slot? integer
---@return integer transferred
function Furnace.pullInput(furnace, from, slot, limit)
    return peripheral.call(furnace, "pullItems", from, slot, limit, inputSlot)
end

---@param furnace string
---@param limit? integer
---@return integer transferred
function Furnace.pullFuelFromInput(furnace, limit)
    return peripheral.call(furnace, "pullItems", furnace, inputSlot, limit, fuelSlot)
end

---@param furnace string
---@param limit? integer
---@return integer transferred
function Furnace.pullFuelFromOutput(furnace, limit)
    return peripheral.call(furnace, "pullItems", furnace, outputSlot, limit, fuelSlot)
end

return Furnace
