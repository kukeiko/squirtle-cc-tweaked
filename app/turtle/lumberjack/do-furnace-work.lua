local Furnace = require "world.furnace"
local Squirtle = require "squirtle"
local Inventory = require "inventory.inventory"

---@param furnace string
---@param buffer string
local function topOffFurnaceFuel(furnace, buffer)
    local missing = Furnace.getMissingFuelCount(furnace)

    for slot, stack in pairs(Inventory.getStacks(buffer)) do
        if stack.name == "minecraft:charcoal" then
            missing = missing - Furnace.pullFuel(furnace, buffer, slot)

            if missing <= 0 then
                break
            end
        end
    end
end

---@param furnace string
---@param buffer string
local function topOffFurnaceInput(furnace, buffer)
    local missing = Furnace.getMissingInputCount(furnace)

    for slot, stack in pairs(Inventory.getStacks(buffer)) do
        if stack.name == "minecraft:birch_log" then
            missing = missing - Furnace.pullInput(furnace, buffer, slot)

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
---@param stash string
---@param io string
return function(furnace, stash, io)
    while Inventory.getItemStock(stash, "minecraft:birch_log") > 0 do
        print("topping off furnace input...")
        topOffFurnaceInput(furnace, stash)

        print("pushing furnace output into buffer...")
        Furnace.pushOutput(furnace, stash)

        print("topping off furnace fuel...")
        topOffFurnaceFuel(furnace, stash)

        print("warming up furnace...")
        kickstartFurnaceFuel(furnace, 8)

        if Inventory.getItemStock(stash, "minecraft:birch_log") > 0 then
            Squirtle.pushOutput(stash, io)

            if Inventory.getItemStock(stash, "minecraft:birch_log") > 0 then
                print("logs leftover, pausing for 30s")
                os.sleep(30)
            end
        end
    end
end
