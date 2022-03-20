local nativeTurtle = turtle
local bitSourceSlot = 15
local bitSlot = 16
local bitItemType = "minecraft:redstone_torch"
local bitDisplayName = "bit"

---@class KiwiInventory
local KiwiInventory = {}

---@return integer
function KiwiInventory.size()
    return 16
end

---@return ItemStack[]
function KiwiInventory.list()
    local list = {}

    for slot = 1, KiwiInventory.size() do
        local item = KiwiInventory.getStack(slot)

        if item then
            list[slot] = item
        end
    end

    return list
end

---@param slot integer
---@param detailed? boolean
---@return ItemStack?
function KiwiInventory.getStack(slot, detailed)
    return nativeTurtle.getItemDetail(slot, detailed)
end

---@param slot integer
function KiwiInventory.selectSlot(slot)
    return nativeTurtle.select(slot)
end

---@param slot integer
---@return integer
function KiwiInventory.numInSlot(slot)
    return nativeTurtle.getItemCount(slot)
end

---@return integer
function KiwiInventory.availableSize()
    local numEmpty = 0

    for slot = 1, KiwiInventory.size() do
        if KiwiInventory.numInSlot(slot) == 0 then
            numEmpty = numEmpty + 1
        end
    end

    return numEmpty
end

---@return boolean
function KiwiInventory.isEmpty()
    for slot = 1, KiwiInventory.size() do
        if KiwiInventory.numInSlot(slot) > 0 then
            return false
        end
    end

    return true
end

---@return boolean
function KiwiInventory.isFull()
    for slot = 1, KiwiInventory.size() do
        if KiwiInventory.numInSlot(slot) == 0 then
            return false
        end
    end

    return true
end

---@param startAt? number
function KiwiInventory.firstEmptySlot(startAt)
    startAt = startAt or 1

    for slot = startAt, KiwiInventory.size() do
        if KiwiInventory.numInSlot(slot) == 0 then
            return slot
        end
    end

    return nil
end

---@return boolean|integer
function KiwiInventory.selectFirstEmptySlot()
    local slot = KiwiInventory.firstEmptySlot()

    if not slot then
        return false
    end

    KiwiInventory.selectSlot(slot)

    return slot
end

---@return boolean|integer
function KiwiInventory.selectFirstOccupiedSlot()
    for slot = 1, KiwiInventory.size() do
        if KiwiInventory.numInSlot(slot) > 0 then
            KiwiInventory.selectSlot(slot)
            return slot
        end
    end

    return false
end

---@return boolean
function KiwiInventory.selectSlotIfNotEmpty(slot)
    if KiwiInventory.numInSlot(slot) > 0 then
        return KiwiInventory.selectSlot(slot)
    else
        return false
    end
end

---@param name string
---@param exact? boolean
function KiwiInventory.find(name, exact)
    for slot = 1, KiwiInventory.size() do
        local item = KiwiInventory.getStack(slot)

        if item and exact and item.name == name then
            return slot
        elseif item and string.find(item.name, name) then
            return slot
        end
    end
end

function KiwiInventory.selectItem(name)
    local slot = KiwiInventory.find(name)

    if not slot then
        return false
    end

    KiwiInventory.selectSlot(slot)

    return slot
end

---@param slot integer
---@param count? integer
function KiwiInventory.transfer(slot, count)
    return nativeTurtle.transferTo(slot, count)
end

function KiwiInventory.moveFirstSlotSomewhereElse()
    if KiwiInventory.numInSlot(1) == 0 then
        return true
    end

    KiwiInventory.selectSlot(1)

    local slot = KiwiInventory.firstEmptySlot()

    if not slot then
        return false
    end

    KiwiInventory.transfer(slot)
end

function KiwiInventory.condense()
    for slot = KiwiInventory.size(), 1, -1 do
        local item = KiwiInventory.getStack(slot)

        if item then
            for targetSlot = 1, slot - 1 do
                local candidate = KiwiInventory.getStack(targetSlot)

                if candidate and candidate.name == item.name then
                    KiwiInventory.selectSlot(slot)
                    KiwiInventory.transfer(targetSlot)

                    if KiwiInventory.numInSlot(slot) == 0 then
                        break
                    end
                elseif not candidate then
                    KiwiInventory.selectSlot(slot)
                    KiwiInventory.transfer(targetSlot)
                    break
                end
            end
        end
    end
end

function KiwiInventory.readBits()
    local stack = KiwiInventory.getStack(bitSlot, true)

    -- [todo] should we error in case there is a stack and it is not
    -- the type of bit item we except?
    if stack and stack.name == bitItemType and stack.displayName:lower() == bitDisplayName then
        return stack.count
    end

    return 0
end

-- [todo] throw errors?
---@param bits integer
function KiwiInventory.setBits(bits)
    local current = KiwiInventory.readBits()

    if current == bits then
        return true
    elseif current < bits then
        KiwiInventory.selectSlot(bitSourceSlot)
        return KiwiInventory.transfer(bitSlot, bits - current)
    elseif current > bits then
        KiwiInventory.selectSlot(bitSlot)
        return KiwiInventory.transfer(bitSourceSlot, current - bits)
    end
end

-- [todo] throw errors?
---@param bits integer
function KiwiInventory.orBits(bits)
    local current = KiwiInventory.readBits()
    local next = bit.bor(bits, current)

    if next ~= current then
        return KiwiInventory.setBits(next)
    end

    return true
end


-- [todo] throw errors?
---@param bits integer
function KiwiInventory.xorBits(bits)
    local current = KiwiInventory.readBits()
    local next = bit.bxor(bits, current)

    if next ~= current then
        return KiwiInventory.setBits(next)
    end

    return true
end

return KiwiInventory
