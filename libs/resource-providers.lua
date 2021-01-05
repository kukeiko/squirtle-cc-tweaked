package.path = package.path .. ";/libs/?.lua"

local FuelDictionary = require "fuel-dictionary";
local Inventory = require "inventory";
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
    local found = {}

    if resources.fuelLevel ~= nil then
        if Inventory.sumFuelLevel() + turtle.getFuelLevel() >= resources.fuelLevel then
            -- [todo] should Inventory.getFuelStacks() return a map? if yes, need to convert to array @ requires.consumeItem
            local allFuelStacks = Inventory.getFuelStacks()
            local requiredFuelStacks = {}
            local missingFuel = resources.fuelLevel - turtle.getFuelLevel()

            for i = 1, #allFuelStacks do
                local stack = allFuelStacks[i]
                local stackRefuelAmount = FuelDictionary.getStackRefuelAmount(stack)

                if stackRefuelAmount <= missingFuel then
                    table.insert(requiredFuelStacks, allFuelStacks[i])
                else
                    local itemRefuelAmount = FuelDictionary.getRefuelAmount(stack.name)
                    local numRequiredItems = math.ceil(missingFuel / itemRefuelAmount)
                    table.insert(requiredFuelStacks, {name = stack.name, count = numRequiredItems})
                end

                missingFuel = missingFuel - stackRefuelAmount
            end

            table.insert(found, {
                provides = {fuelLevel = resources.fuelLevel},
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

    return found
end

return ResourceProviders
