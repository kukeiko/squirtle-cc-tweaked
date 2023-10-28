local Utils = require "utils"
local Inventory = require "inventory.inventory"
local Elemental = require "squirtle.elemental"
local Basic = require "squirtle.basic"

local bucket = "minecraft:bucket"
local fuelItems = {
    -- ["minecraft:lava_bucket"] = 1000,
    ["minecraft:coal"] = 80,
    ["minecraft:charcoal"] = 80,
    ["minecraft:coal_block"] = 800
    -- ["minecraft:bamboo"] = 2
}

---@class Advanced : Basic
local Advanced = {}
setmetatable(Advanced, {__index = Basic})

---@param item string
---@return boolean
local function isFuel(item)
    return fuelItems[item] ~= nil
end

---@param item string
---@return integer
local function getRefuelAmount(item)
    return fuelItems[item] or 0
end

---@param stack table
---@return integer
local function getStackRefuelAmount(stack)
    return getRefuelAmount(stack.name) * stack.count
end

---@param stacks ItemStack[]
---@param fuel number
---@param allowedOverFlow? number
---@return ItemStack[] fuelStacks, number openFuel
local function pickStacks(stacks, fuel, allowedOverFlow)
    allowedOverFlow = math.max(allowedOverFlow or 1000, 0)
    local pickedStacks = {}
    local openFuel = fuel

    -- [todo] try to order stacks based on type of item
    -- for example, we may want to start with the smallest ones to minimize potential overflow
    for slot, stack in pairs(stacks) do
        if isFuel(stack.name) then
            local stackRefuelAmount = getStackRefuelAmount(stack)

            if stackRefuelAmount <= openFuel then
                pickedStacks[slot] = stack
                openFuel = openFuel - stackRefuelAmount
            else
                -- [todo] can be shortened
                -- actually, im not even sure we need the option to provide an allowed overflow
                local itemRefuelAmount = getRefuelAmount(stack.name)
                local numRequiredItems = math.floor(openFuel / itemRefuelAmount)
                local numItemsToPick = numRequiredItems

                if allowedOverFlow > 0 and ((numItemsToPick + 1) * itemRefuelAmount) - openFuel <= allowedOverFlow then
                    numItemsToPick = numItemsToPick + 1
                end
                -- local numRequiredItems = math.ceil(openFuel / itemRefuelAmount)

                -- if (numRequiredItems * itemRefuelAmount) - openFuel <= allowedOverFlow then
                if numItemsToPick > 0 then
                    pickedStacks[slot] = {name = stack.name, count = numItemsToPick}
                    openFuel = openFuel - stackRefuelAmount
                end
            end

            if openFuel <= 0 then
                break
            end
        end
    end

    return pickedStacks, openFuel
end

---@param fuel? integer
local function refuelFromBackpack(fuel)
    fuel = fuel or Basic.missingFuel()
    local fuelStacks = pickStacks(Basic.getStacks(), fuel)
    local emptyBucketSlot = Basic.find(bucket)

    for slot, stack in pairs(fuelStacks) do
        Basic.select(slot)
        Basic.refuel(stack.count)

        local remaining = Basic.getStack(slot)

        if remaining and remaining.name == bucket then
            if (emptyBucketSlot == nil) or (not Basic.transferTo(emptyBucketSlot)) then
                emptyBucketSlot = slot
            end
        end
    end
end

---@param fuel? integer
local function refuelWithHelpFromPlayer(fuel)
    fuel = fuel or Basic.missingFuel()
    local _, y = term.getCursorPos()

    while Basic.getFuelLevel() < fuel do
        term.setCursorPos(1, y)
        term.clearLine()
        local openFuel = fuel - Basic.getFuelLevel()
        term.write(string.format("[help] need %d more fuel please", openFuel))
        term.setCursorPos(1, y + 1)
        os.pullEvent("turtle_inventory")
        refuelFromBackpack(openFuel)
    end
end

---@param fuel integer
function Advanced.refuelTo(fuel)
    if Basic.hasFuel(fuel) then
        return true
    elseif fuel > Basic.getFuelLimit() then
        error(string.format("required fuel is %d more than the tank can hold", fuel - Basic.getFuelLimit()))
    end

    refuelFromBackpack(fuel)

    if not Basic.hasFuel(fuel) then
        refuelWithHelpFromPlayer(fuel)
    end
end
---@param side string
---@param slot integer
---@param quantity? integer
---@return boolean, string?
function Advanced.suckSlot(side, slot, quantity)
    if slot == 1 then
        return Elemental.suck(side, quantity)
    end

    local items = Inventory.getStacks(side)

    if items[1] ~= nil then
        local firstEmptySlot = Utils.firstEmptySlot(items, Inventory.getSize(side))

        if not firstEmptySlot and Basic.isFull() then
            error(string.format("inventory %s is full. i'm also full, so no temporary unloading possible.", side))
        elseif not firstEmptySlot then
            if quantity ~= nil and quantity < items[slot].count then
                -- [todo] implement: if the turtle has at least 2 slots free, we can offload one from chest into 1st turtle slot,
                -- move wanted item within chest, suck that into 2nd turtle slot, and move back item in 1st turtle slot
                error("not yet implemented: container would still be full even after moving slot")
            end

            -- temporarily load first container slot into turtle
            local initialSlot = Elemental.getSelectedSlot()
            Basic.selectFirstEmpty()
            Elemental.suck(side)

            -- move item within inventory to first empty slot of inventory
            Inventory.pushItems(side, side, slot, nil, 1)
            -- [todo] if we want to be super strict, we would have to move the
            -- item we just sucked in back to the first slot after sucking the requested item
            Elemental.drop(side)
            -- pushing back temporarily loaded item
            Elemental.select(initialSlot)
        else
            Inventory.pushItems(side, side, 1, nil, firstEmptySlot)
            Inventory.pushItems(side, side, slot, quantity, 1)
        end
    else
        Inventory.pushItems(side, side, slot, quantity, 1)
    end

    return Elemental.suck(side, quantity)
end

return Advanced
