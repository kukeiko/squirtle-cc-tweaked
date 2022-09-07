local Chest = require "world.chest"
local Backpack = require "squirtle.backpack"
local suck = require "squirtle.suck"
local drop = require "squirtle.drop"
local getStacks = require "inventory.get-stacks"
local getSize = require "inventory.get-size"

local function firstEmptySlot(table, size)
    for index = 1, size do
        if table[index] == nil then
            return index
        end
    end
end

---@param side string
---@param slot integer
---@param limit? integer
---@return any
return function(side, slot, limit)
    if slot == 1 then
        return suck(side, limit)
    end

    local items = getStacks(side)

    if items[1] ~= nil then
        local firstEmptySlot = firstEmptySlot(items, getSize(side))

        if not firstEmptySlot and Backpack.isFull() then
            error("container full. turtle also full, so no temporary unloading possible.")
        elseif not firstEmptySlot then
            if limit ~= nil and limit ~= items[slot].count then
                -- [todo] we're not gonna have a slot free in the container
                error("not yet implemented: container would still be full even after moving slot")
            end

            print("temporarily load first container slot into turtle...")
            local initialSlot = turtle.getSelectedSlot()
            Backpack.selectFirstEmptySlot()
            suck(side)
            Chest.pushItems(side, side, slot, limit, 1)
            -- [todo] if we want to be super strict, we would have to move the
            -- item we just sucked in back to the first slot after sucking the requested item
            drop(side)
            print("pushing back temporarily loaded item")
            turtle.select(initialSlot)
        else
            Chest.pushItems(side, side, 1, nil, firstEmptySlot)
            Chest.pushItems(side, side, slot, limit, 1)
        end
    else
        Chest.pushItems(side, side, slot, limit, 1)
    end

    return suck(side, limit)
end
