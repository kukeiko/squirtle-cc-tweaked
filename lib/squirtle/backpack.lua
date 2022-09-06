local find = require "squirtle.backpack.find"
local getSize = require "squirtle.backpack.get-size"
local getStack = require "squirtle.backpack.get-stack"
local getStacks = require "squirtle.backpack.get-stacks"
local selectItem = require "squirtle.backpack.select-item"
local selectSlot = require "squirtle.backpack.select-slot"

local native = turtle
local Backpack = {}

-- [todo] move bit logic somewhere else?
local bitSourceSlot = 15
local bitSlot = 16
local bitItemType = "minecraft:redstone_torch"
local bitDisplayName = "bit"

---@return integer
function Backpack.size()
    return getSize()
end

---@param slot integer
---@param detailed? boolean
---@return ItemStack?
function Backpack.getStack(slot, detailed)
    return getStack(slot, detailed)
end

---@param slot integer
---@param count? integer
function Backpack.transfer(slot, count)
    return native.transferTo(slot, count)
end

---@return boolean
function Backpack.isEmpty()
    for slot = 1, getSize() do
        if Backpack.numInSlot(slot) > 0 then
            return false
        end
    end

    return true
end

---@return ItemStack[]
function Backpack.getStacks()
    return getStacks()
end

---@return table<string, integer>
function Backpack.getStock()
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(Backpack.getStacks()) do
        stock[stack.name] = (stock[stack.name] or 0) + stack.count
    end

    return stock
end

---@param predicate string|function<boolean, ItemStack>
function Backpack.getItemStock(predicate)
    if type(predicate) == "string" then
        local name = predicate

        ---@param stack ItemStack
        predicate = function(stack)
            return stack.name == name
        end
    end

    local stock = 0

    for _, stack in pairs(Backpack.getStacks()) do
        if predicate(stack) then
            stock = stock + stack.count
        end
    end

    return stock
end

---@param slot integer
function Backpack.selectSlot(slot)
    return selectSlot(slot)
end

---@param slot integer
---@return integer
function Backpack.numInSlot(slot)
    return native.getItemCount(slot)
end

---@return boolean
function Backpack.selectSlotIfNotEmpty(slot)
    if Backpack.numInSlot(slot) > 0 then
        return Backpack.selectSlot(slot)
    else
        return false
    end
end

---@param name string
---@param exact? boolean
function Backpack.find(name, exact)
    return find(name, exact)
end

---@param name string
function Backpack.selectItem(name)
    return selectItem(name)
end

---@param startAt? number
function Backpack.firstEmptySlot(startAt)
    startAt = startAt or 1

    for slot = startAt, Backpack.size() do
        if Backpack.numInSlot(slot) == 0 then
            return slot
        end
    end

    return nil
end

---@return boolean|integer
function Backpack.selectFirstEmptySlot()
    local slot = Backpack.firstEmptySlot()

    if not slot then
        return false
    end

    Backpack.selectSlot(slot)

    return slot
end

function Backpack.readBits()
    local stack = getStack(bitSlot, true)

    -- [todo] should we error in case there is a stack and it is not
    -- the type of bit item we except?
    if stack and stack.name == bitItemType and stack.displayName:lower() == bitDisplayName then
        return stack.count
    end

    return 0
end

-- [todo] throw errors?
---@param bits integer
function Backpack.setBits(bits)
    local current = Backpack.readBits()

    if current == bits then
        return true
    elseif current < bits then
        selectSlot(bitSourceSlot)
        return Backpack.transfer(bitSlot, bits - current)
    elseif current > bits then
        selectSlot(bitSlot)
        return Backpack.transfer(bitSourceSlot, current - bits)
    end
end

-- [todo] throw errors?
---@param bits integer
function Backpack.orBits(bits)
    local current = Backpack.readBits()
    local next = bit.bor(bits, current)

    if next ~= current then
        return Backpack.setBits(next)
    end

    return true
end

-- [todo] throw errors?
---@param bits integer
function Backpack.xorBits(bits)
    local current = Backpack.readBits()
    local next = bit.bxor(bits, current)

    if next ~= current then
        return Backpack.setBits(next)
    end

    return true
end

function Backpack.condense()
    for slot = getSize(), 1, -1 do
        local item = getStack(slot)

        if item then
            for targetSlot = 1, slot - 1 do
                local candidate = getStack(targetSlot, true)

                if candidate and candidate.name == item.name and candidate.count < candidate.maxCount then
                    selectSlot(slot)
                    Backpack.transfer(targetSlot)

                    if Backpack.numInSlot(slot) == 0 then
                        break
                    end
                elseif not candidate then
                    selectSlot(slot)
                    Backpack.transfer(targetSlot)
                    break
                end
            end
        end
    end
end

---@return boolean
function Backpack.isFull()
    for slot = 1, getSize() do
        if Backpack.numInSlot(slot) == 0 then
            return false
        end
    end

    return true
end

return Backpack;
