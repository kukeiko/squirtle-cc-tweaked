local nativeTurtle = turtle

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
---@return ItemStack?
function KiwiInventory.getStack(slot)
    return nativeTurtle.getItemDetail(slot)
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

function KiwiInventory.transfer(slot)
    return nativeTurtle.transferTo(slot)
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

return KiwiInventory
