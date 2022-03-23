local Utils = require "squirtle.libs.utils"
local FuelItems = {}

local items = {["minecraft:lava_bucket"] = 1000, ["minecraft:coal"] = 80, ["minecraft:bamboo"] = 2}

--- @param item string
function FuelItems.isFuel(item)
    return items[item] ~= nil
end

--- @param item string
function FuelItems.getRefuelAmount(item)
    return items[item] or 0
end

--- @param stack table
function FuelItems.getStackRefuelAmount(stack)
    return FuelItems.getRefuelAmount(stack.name) * stack.count
end

---@param stacks ItemStack[]
function FuelItems.filterStacks(stacks)
    local fuelStacks = {}

    for slot, stack in pairs(stacks) do
        if FuelItems.isFuel(stack.name) then
            fuelStacks[slot] = stack
        end
    end

    -- if Utils.isEmpty(fuelStacks) then
    --     return nil
    -- end

    return fuelStacks
end

---@param stacks ItemStack[]
---@param fuel number
---@param allowedOverFlow? number
---@return ItemStack[] fuelStacks, number openFuel
function FuelItems.pickStacks(stacks, fuel, allowedOverFlow)
    allowedOverFlow = math.max(allowedOverFlow or 1000, 0)
    local pickedStacks = {}
    local openFuel = fuel

    -- [todo] try to order stacks based on type of item
    -- for example, we may want to start with the smallest ones to minimize potential overflow
    for slot, stack in pairs(stacks) do
        if FuelItems.isFuel(stack.name) then
            local stackRefuelAmount = FuelItems.getStackRefuelAmount(stack)

            if stackRefuelAmount <= openFuel then
                pickedStacks[slot] = stack
                openFuel = openFuel - stackRefuelAmount
            else
                -- [todo] can be shortened
                -- actually, im not even sure we need the option to provide an allowed overflow
                local itemRefuelAmount = FuelItems.getRefuelAmount(stack.name)
                local numRequiredItems = math.floor(openFuel / itemRefuelAmount)
                local numItemsToPick = numRequiredItems

                if allowedOverFlow > 0 and ((numItemsToPick + 1) * itemRefuelAmount) - openFuel <=
                    allowedOverFlow then
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

    -- if Utils.isEmpty(pickedStacks) then
    --     pickedStacks = nil
    -- end

    return pickedStacks, openFuel
end

return FuelItems
