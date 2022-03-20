local KiwiChet = require "kiwi.core.chest"
local KiwiInventory = require "kiwi.turtle.inventory"
local suck = require "kiwi.turtle.suck"
local drop = require "kiwi.turtle.drop"

local function firstEmptySlotInItems(table, size)
    for index = 1, size do
        if table[index] == nil then
            return index
        end
    end
end

---@param side integer
---@param slot integer
---@param limit? integer
---@return any
return function(side, slot, limit)
    if slot == 1 then
        return suck(side, limit)
    end

    local chest = KiwiChet.new(side)
    local items = chest:getItemList()

    if items[1] ~= nil then
        local firstEmptySlot = firstEmptySlotInItems(items, chest:getSize())

        if not firstEmptySlot and KiwiInventory.isFull() then
            -- [todo] add and use "unloadAnyOneItem()" method from item-transporter
            error("container full. turtle also full, so no temporary unloading possible.")
        elseif not firstEmptySlot then
            if limit ~= nil and limit ~= items[slot].count then
                -- [todo] we're not gonna have a slot free in the container
                error("not yet implemented: container would still be full even after moving slot")
            end

            print("temporarily load first container slot into turtle...")
            local initialSlot = turtle.getSelectedSlot()
            KiwiInventory.selectFirstEmptySlot()
            suck(side)
            chest:pushItems(side, slot, limit, 1)
            -- [todo] if we want to be super strict, we would have to move the
            -- item we just sucked in back to the first slot after sucking the requested item
            drop(side)
            print("pushing back temporarily loaded item")
            turtle.select(initialSlot)
        else
            print("moving first slot to first empty slot")
            chest:pushItems(side, 1, nil, firstEmptySlot)
            chest:pushItems(side, slot, limit, 1)
        end
    else
        chest:pushItems(side, slot, limit, 1)
    end

    return suck(side)
end
