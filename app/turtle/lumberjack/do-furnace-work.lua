local Inventory = require "lib.inventory"
local Furnace = require "lib.inventory.furnace"
local Squirtle = require "lib.squirtle"

---@param furnace string
---@param stash string
local function topOffFurnaceFuel(furnace, stash)
    local missing = Furnace.getMissingFuelCount(furnace)

    for slot, stack in pairs(Inventory.getStacks(stash)) do
        if stack.name == "minecraft:charcoal" then
            missing = missing - Furnace.pullFuel(furnace, stash, slot)

            if missing <= 0 then
                break
            end
        end
    end
end

---@param furnace string
---@param stash string
local function topOffFurnaceInput(furnace, stash)
    local missing = Furnace.getMissingInputCount(furnace)

    for slot, stack in pairs(Inventory.getStacks(stash)) do
        if stack.name == "minecraft:birch_log" then
            missing = missing - Furnace.pullInput(furnace, stash, slot)

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
    local function hasStashedBirchLogs()
        return Inventory.getItemStockByTag(stash, "input", "minecraft:birch_log") > 0
    end

    while hasStashedBirchLogs() do
        print("[furnace] topping off input")
        topOffFurnaceInput(furnace, stash)

        print("[furnace] push output into stash")
        Furnace.pushOutput(furnace, stash)

        print("[furnace] topping off fuel")
        topOffFurnaceFuel(furnace, stash)

        print("[furnace] warming up")
        kickstartFurnaceFuel(furnace, 8)

        if hasStashedBirchLogs() then
            -- [todo] keep 32 birch saplings
            Squirtle.pushOutput(stash, io)

            if hasStashedBirchLogs() then
                print("[waiting] logs leftover, pausing for 30s")
                os.sleep(30)
            end
        end
    end
end
