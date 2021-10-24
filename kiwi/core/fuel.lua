---@class KiwiFuel
local KiwiFuel = {}
local native = turtle

local items = {
    -- ["minecraft:lava_bucket"] = 1000,
    ["minecraft:coal"] = 80,
    ["minecraft:charcoal"] = 80,
    -- ["minecraft:bamboo"] = 2
}

---@param fuel integer
function KiwiFuel.hasFuel(fuel)
    local level = native.getFuelLevel()

    return level == "unlimited" or level >= fuel
end

function KiwiFuel.refuel(count)
    return native.refuel(count)
end

---@return integer
function KiwiFuel.getFuelLevel()
    return native.getFuelLevel()
end

---@return integer
function KiwiFuel.getFuelLimit()
    return native.getFuelLimit()
end

---@param limit integer
---@return integer
function KiwiFuel.getMissingFuel(limit)
    local fuelLevel = KiwiFuel.getFuelLevel()

    if fuelLevel == "unlimited" then
        return 0
    end

    if not limit then
        limit = KiwiFuel.getFuelLimit()
    end

    return limit - KiwiFuel.getFuelLevel()
end

--- @param item string
function KiwiFuel.isFuel(item)
    return items[item] ~= nil
end

--- @param item string
function KiwiFuel.getRefuelAmount(item)
    return items[item] or 0
end

--- @param stack table
function KiwiFuel.getStackRefuelAmount(stack)
    return KiwiFuel.getRefuelAmount(stack.name) * stack.count
end

---@param stacks KiwiItemStack[]
function KiwiFuel.filterStacks(stacks)
    local fuelStacks = {}

    for slot, stack in pairs(stacks) do
        if KiwiFuel.isFuel(stack.name) then
            fuelStacks[slot] = stack
        end
    end

    return fuelStacks
end

---@param stacks KiwiItemStack[]
---@param fuel number
---@param allowedOverFlow? number
---@return KiwiItemStack[] fuelStacks, number openFuel
function KiwiFuel.pickStacks(stacks, fuel, allowedOverFlow)
    allowedOverFlow = math.max(allowedOverFlow or 1000, 0)
    local pickedStacks = {}
    local openFuel = fuel

    -- [todo] try to order stacks based on type of item
    -- for example, we may want to start with the smallest ones to minimize potential overflow
    for slot, stack in pairs(stacks) do
        if KiwiFuel.isFuel(stack.name) then
            local stackRefuelAmount = KiwiFuel.getStackRefuelAmount(stack)

            if stackRefuelAmount <= openFuel then
                pickedStacks[slot] = stack
                openFuel = openFuel - stackRefuelAmount
            else
                -- [todo] can be shortened
                -- actually, im not even sure we need the option to provide an allowed overflow
                local itemRefuelAmount = KiwiFuel.getRefuelAmount(stack.name)
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

---@param stacks KiwiItemStack[]
function KiwiFuel.sumFuel(stacks)
    local fuel = 0

    for _, stack in pairs(stacks) do
        if KiwiFuel.isFuel(stack.name) then
            fuel = fuel + KiwiFuel.getStackRefuelAmount(stack)
        end
    end

    return fuel
end

return KiwiFuel
