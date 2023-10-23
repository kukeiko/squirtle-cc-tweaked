local find = require "squirtle.backpack.find"
local selectSlot = require "squirtle.backpack.select-slot"
local getStacks = require "inventory.get-stacks"
local suckSlotFromChest = require "squirtle.transfer.suck-slot-from-chest"

---@return string? direction
local function placeAnywhere()
    if turtle.place() then
        return "front"
    end

    if turtle.placeUp() then
        return "top"
    end

    if turtle.placeDown() then
        return "bottom"
    end
end

---@param side string
local function digSide(side)
    if side == "front" then
        turtle.dig()
    elseif side == "top" then
        turtle.digUp()
    elseif side == "bottom" then
        turtle.digDown()
    end
end

---@param side string
local function dropSide(side)
    if side == "front" then
        turtle.drop()
    elseif side == "top" then
        turtle.dropUp()
    elseif side == "bottom" then
        turtle.dropDown()
    end
end

-- [todo] hack: copied & adapted from Backpack.lua
local function firstEmptySlot()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            return slot
        end
    end

    return nil
end

---@param alsoIgnoreSlot integer
---@return integer?
local function nextSlotThatIsNotShulker(alsoIgnoreSlot)
    for slot = 1, 16 do
        if alsoIgnoreSlot ~= slot then
            local item = turtle.getItemDetail(slot)

            if item.name ~= "minecraft:shulker_box" then
                return slot
            end
        end
    end
end

---@param shulker integer
---@param item string
---@return boolean
local function loadFromShulker(shulker, item)
    selectSlot(shulker)

    local placedSide = placeAnywhere()

    if not placedSide then
        return false
    end

    while not peripheral.isPresent(placedSide) do
        os.sleep(.1)
    end

    local stacks = getStacks(placedSide)

    for stackSlot, stack in pairs(stacks) do
        if stack.name == item then
            suckSlotFromChest(placedSide, stackSlot)
            local emptySlot = firstEmptySlot()

            if not emptySlot then
                local slotToPutIntoShulker = nextSlotThatIsNotShulker(shulker)

                if not slotToPutIntoShulker then
                    error("i seem to be full with shulkers")
                end

                turtle.select(slotToPutIntoShulker)
                dropSide(placedSide)
                turtle.select(shulker)
            end

            digSide(placedSide)

            return true
        end
    end

    digSide(placedSide)

    return false
end

-- [todo] consider adding requireItems() logic here
-- [update] not every app would want that though, e.g. check out farmer app
---@param name string
---@param exact? boolean
---@return false|integer
return function(name, exact)
    local slot = find(name, exact)

    if not slot then
        local nextShulkerSlot = 1

        while true do
            local shulker = find("minecraft:shulker_box", true, nextShulkerSlot)

            if not shulker then
                break
            end

            if loadFromShulker(shulker, name) then
                -- [note] we can return "shulker" here because the item loaded from the shulker box ends
                -- up in the slot the shulker originally was
                return shulker
            end

            nextShulkerSlot = nextShulkerSlot + 1
        end

        return false
    end

    selectSlot(slot)

    return slot
end
