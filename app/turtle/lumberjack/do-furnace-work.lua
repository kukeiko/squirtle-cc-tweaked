local Chest = require "world.chest"
local Furnace = require "world.furnace"
local pushOutput = require "squirtle.transfer.push-output"

local function topOffFurnaceFuel(furnaceSide, bufferSide)
    local missing = Furnace.getMissingFuelCount(furnaceSide)

    for slot, stack in pairs(Chest.getStacks(bufferSide)) do
        if stack.name == "minecraft:charcoal" then
            missing = missing - Furnace.pullFuel(furnaceSide, bufferSide, slot)

            if missing <= 0 then
                break
            end
        end
    end
end

local function topOffFurnaceInput(furnaceSide, bufferSide)
    local missing = Furnace.getMissingInputCount(furnaceSide)

    for slot, stack in pairs(Chest.getStacks(bufferSide)) do
        if stack.name == "minecraft:birch_log" then
            missing = missing - Furnace.pullInput(furnaceSide, bufferSide, slot)

            if missing <= 0 then
                break
            end
        end
    end
end

---@param furnace string
---@param count integer
local function kickstartFurnaceFuel(furnace, count)
    local fuelStack = Furnace.getFuelStack(furnace)

    if not fuelStack then
        print("furnace has no fuel, pushing 1x log from input to fuel")
        Furnace.pullFuelFromInput(furnace, 1)
        print("waiting for log to be turned into charcoal")

        while not Furnace.getOutputStack(furnace) do
            os.sleep(1)
        end

        print("output ready! pushing to fuel...")
        Furnace.pullFuelFromOutput(furnace, 1)
    end

    while Furnace.getFuelCount(furnace) < count and Furnace.getInputStack(furnace) do
        print("trying to get", count - Furnace.getFuelCount(furnace), "more coal into fuel slot...")

        while not Furnace.getOutputStack(furnace) do
            if not Furnace.getInputStack(furnace) then
                print("no input to burn, exiting")
                break
            end

            os.sleep(1)
        end

        Furnace.pullFuelFromOutput(furnace)
    end
end

---@param furnace string
---@param buffer string
---@param io string
return function(furnace, buffer, io)
    while Chest.getItemStock(buffer, "minecraft:birch_log") > 0 do
        print("topping off furnace input...")
        topOffFurnaceInput(furnace, buffer)

        print("pushing furnace output into buffer...")
        Furnace.pushOutput(furnace, buffer)

        print("topping off furnace fuel...")
        topOffFurnaceFuel(furnace, buffer)

        print("warming up furnace...")
        kickstartFurnaceFuel(furnace, 8)

        if Chest.getItemStock(buffer, "minecraft:birch_log") > 0 then
            pushOutput(buffer, io)

            if Chest.getItemStock(buffer, "minecraft:birch_log") > 0 then
                print("logs leftover, pausing for 30s")
                os.sleep(30)
            end
        end
    end
end
