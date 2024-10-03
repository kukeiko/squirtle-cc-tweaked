local FurnacePeripheral = {}

local inputSlot = 1
local fuelSlot = 2
local outputSlot = 3

---@param furnace string
---@return ItemStack
function FurnacePeripheral.getInputStack(furnace)
    return peripheral.call(furnace, "getItemDetail", inputSlot)
end

---@param furnace string
function FurnacePeripheral.getMissingInputCount(furnace)
    local stack = FurnacePeripheral.getInputStack(furnace)

    if not stack then
        return 64
    end

    return stack.maxCount - stack.count
end

---@param furnace string
---@return ItemStack
function FurnacePeripheral.getFuelStack(furnace)
    return peripheral.call(furnace, "getItemDetail", fuelSlot)
end

---@param furnace string
---@return integer
function FurnacePeripheral.getMissingFuelCount(furnace)
    local stack = FurnacePeripheral.getFuelStack(furnace)

    if not stack then
        return 64
    end

    return stack.maxCount - stack.count
end

---@param furnace string
---@return ItemStack
function FurnacePeripheral.getOutputStack(furnace)
    return peripheral.call(furnace, "getItemDetail", outputSlot)
end

---@param furnace string
---@param to string
---@param limit? integer
---@param slot? integer
---@return integer transferred
function FurnacePeripheral.pushOutput(furnace, to, limit, slot)
    return peripheral.call(furnace, "pushItems", to, outputSlot, limit, slot)
end

---@param furnace string
---@param from string
---@param limit? integer
---@param slot? integer
---@return integer transferred
function FurnacePeripheral.pullFuel(furnace, from, slot, limit)
    return peripheral.call(furnace, "pullItems", from, slot, limit, fuelSlot)
end

function FurnacePeripheral.getFuelCount(side)
    local fuelStack = FurnacePeripheral.getFuelStack(side)

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
function FurnacePeripheral.pullInput(furnace, from, slot, limit)
    return peripheral.call(furnace, "pullItems", from, slot, limit, inputSlot)
end

---@param furnace string
---@param limit? integer
---@return integer transferred
function FurnacePeripheral.pullFuelFromInput(furnace, limit)
    return peripheral.call(furnace, "pullItems", furnace, inputSlot, limit, fuelSlot)
end

---@param furnace string
---@param limit? integer
---@return integer transferred
function FurnacePeripheral.pullFuelFromOutput(furnace, limit)
    return peripheral.call(furnace, "pullItems", furnace, outputSlot, limit, fuelSlot)
end

return FurnacePeripheral
