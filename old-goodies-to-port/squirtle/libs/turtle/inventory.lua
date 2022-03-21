local FuelItems = require "squirtle.libs.fuel-items"
local Turtle = require "squirtle.libs.turtle"
local Inventory = {}

function Inventory.size()
    return 16
end

function Inventory.availableSize()
    local numEmpty = 0

    for slot = 1, Inventory.size() do
        if Turtle.getItemCount(slot) == 0 then
            numEmpty = numEmpty + 1
        end
    end

    return numEmpty
end

function Inventory.isEmpty()
    for slot = 1, Inventory.size() do
        if Turtle.getItemCount(slot) > 0 then
            return false
        end
    end

    return true
end

function Inventory.isFull()
    for slot = 1, Inventory.size() do
        if Turtle.getItemCount(slot) == 0 then
            return false
        end
    end

    return true
end

---@param startAt? number
function Inventory.firstEmptySlot(startAt)
    startAt = startAt or 1

    for slot = startAt, Inventory.size() do
        if Turtle.getItemCount(slot) == 0 then
            return slot
        end
    end

    return nil
end

function Inventory.selectFirstEmptySlot()
    local slot = Inventory.firstEmptySlot()

    if not slot then
        return false
    end

    Turtle.select(slot)

    return slot
end

function Inventory.selectFirstOccupiedSlot()
    for slot = 1, Inventory.size() do
        if Turtle.getItemCount(slot) > 0 then
            Turtle.select(slot)
            return slot
        end
    end

    return false
end

function Inventory.selectSlotIfNotEmpty(slot)
    if Turtle.getItemCount(slot) > 0 then
        return Turtle.select(slot)
    else
        return false
    end
end

---@param name string
---@param exact? boolean
function Inventory.find(name, exact)
    for slot = 1, Inventory.size() do
        local item = Turtle.getItemDetail(slot)

        if item and exact and item.name == name then
            return slot
        elseif item and string.find(item.name, name) then
            return slot
        end
    end
end

function Inventory.selectItem(name)
    local slot = Inventory.find(name)

    if not slot then
        return false
    end

    Turtle.select(slot)

    return slot
end

function Inventory.moveFirstSlotSomewhereElse()
    if Turtle.getItemCount(1) == 0 then
        return true
    end

    Turtle.select(1)

    local slot = Inventory.firstEmptySlot()

    if not slot then
        return false
    end

    Turtle.transferTo(slot)
end

function Inventory.dumpTo(side)
    for slot = 1, Inventory.size() do
        if Turtle.getItemCount(slot) > 0 then
            Turtle.select(slot)
            Turtle.dropAt(side)
        end
    end

    return Inventory.isEmpty()
end

function Inventory.condense()
    for slot = Inventory.size(), 1, -1 do
        local item = Turtle.getItemDetail(slot)

        if item then
            for targetSlot = 1, slot - 1 do
                local candidate = Turtle.getItemDetail(targetSlot)

                if candidate and candidate.name == item.name then
                    Turtle.select(slot)
                    Turtle.transferTo(targetSlot)
                    if Turtle.getItemCount(slot) == 0 then
                        break
                    end
                elseif not candidate then
                    Turtle.select(slot)
                    Turtle.transferTo(targetSlot)
                    break
                end
            end
        end
    end
end

function Inventory.sumFuelLevel()
    local fuelSlots = Inventory.getFuelSlots()
    local fuel = 0

    for i = 1, #fuelSlots do
        fuel = fuel + FuelItems.getStackRefuelAmount(Turtle.getItemDetail(fuelSlots[i]))
    end

    return fuel
end

function Inventory.getFuelSlots()
    local fuelSlots = {}

    for slot = 1, Inventory.size() do
        if Turtle.getItemCount(slot) > 0 and FuelItems.isFuel(Turtle.getItemDetail(slot).name) then
            table.insert(fuelSlots, slot)
        end
    end

    return fuelSlots
end

function Inventory.getFuelStacks()
    local fuelStacks = {}

    for slot = 1, Inventory.size() do
        local stack = Turtle.getItemDetail(slot)

        if stack ~= nil and FuelItems.isFuel(stack.name) then
            table.insert(fuelStacks, stack)
        end
    end

    return fuelStacks
end

---@return ItemStack[]
function Inventory.list()
    local list = {}

    for slot = 1, Inventory.size() do
        local item = Turtle.getItemDetail(slot)

        if item then
            list[slot] = item
        end
    end

    return list
end

---@param slot integer
---@return ItemStack?
function Inventory.getStack(slot)
    return Turtle.getItemDetail(slot)
end

return Inventory
