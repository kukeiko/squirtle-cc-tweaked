local nativeTurtle = turtle
local bitSourceSlot = 15
local bitSlot = 16
local bitItemType = "minecraft:redstone_torch"
local bitDisplayName = "bit"

---@class Inventory
local Inventory = {}

---@return integer
function Inventory.size()
    return 16
end

---@return ItemStack[]
function Inventory.list()
    local list = {}

    for slot = 1, Inventory.size() do
        local item = Inventory.getStack(slot)

        if item then
            list[slot] = item
        end
    end

    return list
end

---@param slot integer
---@param detailed? boolean
---@return ItemStack?
function Inventory.getStack(slot, detailed)
    return nativeTurtle.getItemDetail(slot, detailed)
end

---@param slot integer
function Inventory.selectSlot(slot)
    return nativeTurtle.select(slot)
end

---@param slot integer
---@return integer
function Inventory.numInSlot(slot)
    return nativeTurtle.getItemCount(slot)
end

---@return integer
function Inventory.availableSize()
    local numEmpty = 0

    for slot = 1, Inventory.size() do
        if Inventory.numInSlot(slot) == 0 then
            numEmpty = numEmpty + 1
        end
    end

    return numEmpty
end

---@return boolean
function Inventory.isEmpty()
    for slot = 1, Inventory.size() do
        if Inventory.numInSlot(slot) > 0 then
            return false
        end
    end

    return true
end

---@return boolean
function Inventory.isFull()
    for slot = 1, Inventory.size() do
        if Inventory.numInSlot(slot) == 0 then
            return false
        end
    end

    return true
end

---@param startAt? number
function Inventory.firstEmptySlot(startAt)
    startAt = startAt or 1

    for slot = startAt, Inventory.size() do
        if Inventory.numInSlot(slot) == 0 then
            return slot
        end
    end

    return nil
end

---@return boolean|integer
function Inventory.selectFirstEmptySlot()
    local slot = Inventory.firstEmptySlot()

    if not slot then
        return false
    end

    Inventory.selectSlot(slot)

    return slot
end

---@return boolean|integer
function Inventory.selectFirstOccupiedSlot()
    for slot = 1, Inventory.size() do
        if Inventory.numInSlot(slot) > 0 then
            Inventory.selectSlot(slot)
            return slot
        end
    end

    return false
end

---@return boolean
function Inventory.selectSlotIfNotEmpty(slot)
    if Inventory.numInSlot(slot) > 0 then
        return Inventory.selectSlot(slot)
    else
        return false
    end
end

---@param name string
---@param exact? boolean
function Inventory.find(name, exact)
    for slot = 1, Inventory.size() do
        local item = Inventory.getStack(slot)

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

    Inventory.selectSlot(slot)

    return slot
end

---@param slot integer
---@param count? integer
function Inventory.transfer(slot, count)
    return nativeTurtle.transferTo(slot, count)
end

function Inventory.moveFirstSlotSomewhereElse()
    if Inventory.numInSlot(1) == 0 then
        return true
    end

    Inventory.selectSlot(1)

    local slot = Inventory.firstEmptySlot()

    if not slot then
        return false
    end

    Inventory.transfer(slot)
end

function Inventory.condense()
    for slot = Inventory.size(), 1, -1 do
        local item = Inventory.getStack(slot)

        if item then
            for targetSlot = 1, slot - 1 do
                local candidate = Inventory.getStack(targetSlot, true)

                if candidate and candidate.name == item.name and candidate.count < candidate.maxCount then
                    Inventory.selectSlot(slot)
                    Inventory.transfer(targetSlot)

                    if Inventory.numInSlot(slot) == 0 then
                        break
                    end
                elseif not candidate then
                    Inventory.selectSlot(slot)
                    Inventory.transfer(targetSlot)
                    break
                end
            end
        end
    end
end

function Inventory.readBits()
    local stack = Inventory.getStack(bitSlot, true)

    -- [todo] should we error in case there is a stack and it is not
    -- the type of bit item we except?
    if stack and stack.name == bitItemType and stack.displayName:lower() == bitDisplayName then
        return stack.count
    end

    return 0
end

-- [todo] throw errors?
---@param bits integer
function Inventory.setBits(bits)
    local current = Inventory.readBits()

    if current == bits then
        return true
    elseif current < bits then
        Inventory.selectSlot(bitSourceSlot)
        return Inventory.transfer(bitSlot, bits - current)
    elseif current > bits then
        Inventory.selectSlot(bitSlot)
        return Inventory.transfer(bitSourceSlot, current - bits)
    end
end

-- [todo] throw errors?
---@param bits integer
function Inventory.orBits(bits)
    local current = Inventory.readBits()
    local next = bit.bor(bits, current)

    if next ~= current then
        return Inventory.setBits(next)
    end

    return true
end

-- [todo] throw errors?
---@param bits integer
function Inventory.xorBits(bits)
    local current = Inventory.readBits()
    local next = bit.bxor(bits, current)

    if next ~= current then
        return Inventory.setBits(next)
    end

    return true
end

return Inventory
