package.path = package.path .. ";/libs/?.lua"

local FuelDictionary = require "fuel-dictionary";
local Inventory = require "inventory";
local Resources = require "resources"
local Squirtle = require "squirtle";
local Utils = require "utils";

---@class ResourceProviders
local ResourceProviders = {providers = {}}

function ResourceProviders.new()
    local instance = {}

    setmetatable(instance, {__index = ResourceProviders})

    return instance
end

-- function ResourceProviders:add(provider)
--     table.insert(self.providers, provider)
-- end

function ResourceProviders:find(resources)
    local providers = {}

    if resources.fuelLevel ~= nil then
        -- if Inventory.sumFuelLevel() + turtle.getFuelLevel() >= resources.fuelLevel then
        if Inventory.sumFuelLevel() > 0 then
            -- [todo] should Inventory.getFuelStacks() return a map? if yes, need to convert to array @ requires.consumeItem
            local allFuelStacks = Inventory.getFuelStacks()
            local requiredFuelStacks = {}
            local openFuel = resources.fuelLevel - turtle.getFuelLevel()

            for i = 1, #allFuelStacks do
                local stack = allFuelStacks[i]
                local stackRefuelAmount = FuelDictionary.getStackRefuelAmount(stack)

                if stackRefuelAmount <= openFuel then
                    table.insert(requiredFuelStacks, allFuelStacks[i])
                else
                    local itemRefuelAmount = FuelDictionary.getRefuelAmount(stack.name)
                    local numRequiredItems = math.ceil(openFuel / itemRefuelAmount)
                    table.insert(requiredFuelStacks, {name = stack.name, count = numRequiredItems})
                end

                openFuel = openFuel - stackRefuelAmount
            end

            table.insert(providers, {
                provides = {fuelLevel = resources.fuelLevel - openFuel},
                requires = {consumeItem = requiredFuelStacks},
                execute = function()
                    for i = 1, #requiredFuelStacks do
                        local stack = requiredFuelStacks[i]
                        local open = stack.count

                        while open > 0 do
                            if not Squirtle.selectItem(stack.name) then
                                error("required fuel stack no longer available")
                            end

                            local itemsAvailable = turtle.getItemCount()
                            print("refuel " .. open .. " from slot " .. turtle.getSelectedSlot())
                            turtle.refuel(open)
                            local itemsConsumed = itemsAvailable - turtle.getItemCount()

                            open = open - itemsConsumed
                        end
                    end
                end
            })
        end
    end

    if resources.consumeItem ~= nil then
        local openStacks = {}

        for i = 1, #resources.consumeItem do
            local stack = resources.consumeItem[i]
            local consolidatedStack = openStacks[stack.name]

            if not consolidatedStack then
                openStacks[stack.name] = Utils.copy(stack)
            else
                consolidatedStack.count = consolidatedStack.count + stack.count
            end
        end

        -- print("consolidated:")
        -- Utils.prettyPrint(openStacks)

        local providable = {}

        for slot = 1, Inventory.size() do
            local item = turtle.getItemDetail(slot)

            if item and openStacks[item.name] and openStacks[item.name].count > 0 then
                local open = openStacks[item.name]
                local consumable = math.min(item.count, open.count)
                open.count = open.count - consumable

                if not providable[item.name] then
                    providable[item.name] = {name = item.name, count = consumable}
                else
                    providable[item.name].count = providable[item.name].count + consumable
                end
            end
        end

        -- print("providable:")
        -- Utils.prettyPrint(providable)

        if Utils.count(providable) > 0 then
            local providableArray = {}

            for _, v in pairs(providable) do
                table.insert(providableArray, v)
            end

            table.insert(providers, {
                provides = {consumeItem = providableArray},
                requires = {},
                execute = function()
                    for i = 1, #providable do
                        print("reserve item: " .. providable[i].count .. "x " .. providable[i].name)
                    end
                end
            })
        end
    end

    return providers
end

function ResourceProviders:expand(resources, iteration)
    iteration = iteration or 1

    if iteration > 7 then
        error("expansion too deep")
    end

    local found = self:find(resources)

    print("reducing... ")

    -- Utils.prettyPrint(resources)

    for i = 1, #found do
        resources = Resources.reduce(resources, found[i].provides)
    end

    if resources ~= nil then
        print("could not meet resource requirements:")
        Utils.prettyPrint(resources)
        return false, "could not meet resource requirements"
    end

    print("merging additional resources...")

    local additional = {}

    for i = 1, #found do
        additional = Resources.merge(additional, found[i].requires or {})
    end

    if Utils.count(additional) == 0 then
        print("no additional resources required")
    else
        print("need moar resources, expanding further...")
        -- Utils.prettyPrint(additional)

        self:expand(additional, iteration + 1)
    end
end

return ResourceProviders
