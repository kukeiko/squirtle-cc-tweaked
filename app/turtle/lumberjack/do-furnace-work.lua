local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local FurnacePeripheral = require "lib.peripherals.furnace-peripheral"
local InventoryApi = require "lib.apis.inventory.inventory-api"

---@param furnace string
---@param stash string
local function topOffFurnaceFuel(furnace, stash)
    print("[furnace] topping off fuel")
    local missing = FurnacePeripheral.getMissingFuelCount(furnace)

    for slot, stack in pairs(InventoryPeripheral.getStacks(stash)) do
        if stack.name == "minecraft:charcoal" then
            missing = missing - FurnacePeripheral.pullFuel(furnace, stash, slot)

            if missing <= 0 then
                break
            end
        end
    end
end

---@param furnace string
---@param stash string
local function topOffFurnaceInput(furnace, stash)
    print("[furnace] topping off input")
    local missing = FurnacePeripheral.getMissingInputCount(furnace)

    for slot, stack in pairs(InventoryPeripheral.getStacks(stash)) do
        if stack.name == "minecraft:birch_log" then
            missing = missing - FurnacePeripheral.pullInput(furnace, stash, slot)

            if missing <= 0 then
                break
            end
        end
    end
end

---@param furnace string
---@param count integer
local function kickstartFurnaceFuel(furnace, count)
    local fuelStack = FurnacePeripheral.getFuelStack(furnace)

    if not fuelStack then
        print("[furnace] has no fuel, pushing 1x log from input to fuel")
        FurnacePeripheral.pullFuelFromInput(furnace, 1)
        print("[waiting] for log to be turned into charcoal")

        while not FurnacePeripheral.getOutputStack(furnace) do
            os.sleep(1)
        end

        print("[ready] birch log burned! pushing to fuel...")
        FurnacePeripheral.pullFuelFromOutput(furnace, 1)
    end

    while FurnacePeripheral.getFuelCount(furnace) < count and FurnacePeripheral.getInputStack(furnace) do
        print("[trying] to get", count - FurnacePeripheral.getFuelCount(furnace), "more coal into fuel slot...")

        while not FurnacePeripheral.getOutputStack(furnace) do
            if not FurnacePeripheral.getInputStack(furnace) then
                print("[done] no input to burn, exiting")
                break
            end

            os.sleep(1)
        end

        FurnacePeripheral.pullFuelFromOutput(furnace)
    end
end

---@param stash string
---@return boolean
local function hasStashedBirchLogs(stash)
    return InventoryPeripheral.getItemCount(stash, "minecraft:birch_log") > 0
end

---@param furnace string
---@param stash string
---@param io string
---@param charcoalForRefuel integer
---@return boolean
local function shouldProduceMoreCharcoal(furnace, stash, io, charcoalForRefuel)
    local charcoalInFurnace = FurnacePeripheral.getOutputCount(furnace)
    local charcoalInStash = InventoryPeripheral.getItemCount(stash, "minecraft:charcoal")
    local missingCharcoalInIO = InventoryApi.getItemOpenCount({io}, "minecraft:charcoal", "output")

    return hasStashedBirchLogs(stash) and (charcoalInFurnace + charcoalInStash) < (missingCharcoalInIO + charcoalForRefuel)
end

---@param furnace string
---@param stash string
---@param io string
---@param charcoalForRefuel integer
return function(furnace, stash, io, charcoalForRefuel)
    while shouldProduceMoreCharcoal(furnace, stash, io, charcoalForRefuel) do
        topOffFurnaceInput(furnace, stash)
        print("[furnace] push output into stash")
        FurnacePeripheral.pushOutput(furnace, stash)
        topOffFurnaceFuel(furnace, stash)
        kickstartFurnaceFuel(furnace, 8)

        if shouldProduceMoreCharcoal(furnace, stash, io, charcoalForRefuel) then
            print("[waiting] need more charcoal, pausing for 30s")
            os.sleep(30)
        end
    end
end
