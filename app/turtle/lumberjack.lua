if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

package.path = package.path .. ";/app/turtle/?.lua"
local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ItemApi = require "lib.apis.item-api"
local InventoryApi = require "lib.apis.inventory.inventory-api"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local RemoteService = require "lib.systems.runtime.remote-service"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local FurnacePeripheral = require "lib.peripherals.furnace-peripheral"

local maxLogs = 64
local minBoneMealForPlanting = 1
local minBoneMealForWork = 63
local maxPulledBoneMeal = 63 * 3
local minFuel = 63 * 80
local minSaplings = 32

---@param block Block
---@return string
local function getBlockTurnSide(block)
    if block.name == ItemApi.spruceFence then
        return "left"
    elseif block.name == ItemApi.oakFence then
        return "right"
    else
        return "left"
    end
end

local function isHome()
    return TurtleApi.probe("bottom", ItemApi.barrel) ~= nil
end

local function isParked()
    return isHome() and TurtleApi.probe("front", ItemApi.chest) ~= nil
end

local function isAtWork()
    return TurtleApi.probe("bottom", {ItemApi.dirt, ItemApi.grassBlock}) ~= nil
end

local function isLookingAtTree()
    return TurtleApi.probe("front", {ItemApi.birchSapling, ItemApi.birchLog})
end

local function putCharcoalIntoFurnaceFuel()
    local missing = FurnacePeripheral.getMissingFuelCount("front")

    if missing == 0 then
        return
    end

    print("[furnace] topping off fuel")

    for slot, stack in pairs(InventoryPeripheral.getStacks("bottom")) do
        if stack.name == ItemApi.charcoal then
            missing = missing - FurnacePeripheral.pullFuel("front", "bottom", slot)

            if missing <= 0 then
                break
            end
        end
    end
end

local function putLogsIntoFurnaceInput()
    local missing = FurnacePeripheral.getMissingInputCount("front")

    if missing == 0 then
        return
    end

    print("[furnace] topping off logs to burn")

    for slot, stack in pairs(InventoryPeripheral.getStacks("bottom")) do
        if stack.name == ItemApi.birchLog then
            missing = missing - FurnacePeripheral.pullInput("front", "bottom", slot)

            if missing <= 0 then
                break
            end
        end
    end
end

---@param count integer
local function kickstartFurnaceFuel(count)
    local fuelStack = FurnacePeripheral.getFuelStack("front")

    if not fuelStack then
        print("[furnace] has no fuel, pushing 1x log from input to fuel")
        FurnacePeripheral.pullFuelFromInput("front", 1)
        print("[waiting] for log to be turned into charcoal")

        while not FurnacePeripheral.getOutputStack("front") do
            os.sleep(1)
        end

        print("[ready] birch log burned! pushing to fuel...")
        FurnacePeripheral.pullFuelFromOutput("front", 1)
    end

    while FurnacePeripheral.getFuelCount("front") < count and FurnacePeripheral.getInputStack("front") do
        print("[trying] to get", count - FurnacePeripheral.getFuelCount("front"), "more coal into fuel slot...")

        while not FurnacePeripheral.getOutputStack("front") do
            if not FurnacePeripheral.getInputStack("front") then
                print("[done] no input to burn, exiting")
                break
            end

            os.sleep(1)
        end

        FurnacePeripheral.pullFuelFromOutput("front")
    end
end

---@param charcoalForRefuel integer
---@param missingCharcoalInIO integer
---@return boolean
local function shouldProduceMoreCharcoal(charcoalForRefuel, missingCharcoalInIO)
    local charcoalInFurnace = FurnacePeripheral.getOutputCount("front")
    local charcoalInStash = InventoryPeripheral.getItemCount("bottom", ItemApi.charcoal)
    local hasStashedBirchLogs = InventoryPeripheral.getItemCount("bottom", ItemApi.birchLog) > 0

    return hasStashedBirchLogs and (charcoalInFurnace + charcoalInStash) < (missingCharcoalInIO + charcoalForRefuel)
end

---@param charcoalForRefuel integer
---@param missingCharcoalInIO integer
local function doFurnaceWork(charcoalForRefuel, missingCharcoalInIO)
    TurtleApi.turn("right")

    while shouldProduceMoreCharcoal(charcoalForRefuel, missingCharcoalInIO) do
        putLogsIntoFurnaceInput()
        print("[furnace] push charcoal into stash")
        FurnacePeripheral.pushOutput("front", "bottom")
        putCharcoalIntoFurnaceFuel()
        kickstartFurnaceFuel(8)

        if shouldProduceMoreCharcoal(charcoalForRefuel, missingCharcoalInIO) then
            print("[waiting] need more charcoal, pausing for 30s")
            os.sleep(30)
        end
    end

    os.sleep(1)
    TurtleApi.turn("left")
end

local function doHomework()
    print("[reached] home! dumping logs...")
    TurtleApi.dump("bottom", {ItemApi.birchLog})
    print("[checking] the furnace...")
    local missingCharcoalInIO = InventoryApi.getItemOpenCount({"front"}, ItemApi.charcoal, "output")
    local requiredFuelCharcoal = math.ceil(TurtleApi.missingFuel(minFuel) / 80)
    doFurnaceWork(requiredFuelCharcoal, missingCharcoalInIO)

    TurtleApi.doHomework({
        barrel = "bottom",
        ioChest = "front",
        minFuel = minFuel,
        drainDropper = "bottom",
        input = {required = {[ItemApi.boneMeal] = minBoneMealForWork}, max = {[ItemApi.boneMeal] = maxPulledBoneMeal}},
        output = {kept = {[ItemApi.birchSapling] = minSaplings}, ignoreIfFull = {ItemApi.birchSapling, ItemApi.charcoal}}
    })

    TurtleApi.requireItem(ItemApi.birchSapling, 1)
end

local function plantTree()
    print("[planting] tree...")
    TurtleApi.walk("back")
    TurtleApi.put("front", ItemApi.birchSapling)

    while not TurtleApi.probe("front", ItemApi.birchLog) and TurtleApi.use("front", ItemApi.boneMeal) do
    end

    return TurtleApi.probe("front", ItemApi.birchLog)
end

local function shouldPlantTree()
    local stock = TurtleApi.getStock()
    local needsMoreLogs = (stock[ItemApi.birchLog] or 0) < maxLogs
    local hasBoneMeal = (stock[ItemApi.boneMeal] or 0) >= minBoneMealForPlanting
    local hasSaplings = (stock[ItemApi.birchSapling] or 0) > 0

    return hasSaplings and needsMoreLogs and hasBoneMeal
end

local function refuelFromBackpack()
    while TurtleApi.missingFuel() > 0 and TurtleApi.selectItem(ItemApi.stick) do
        print("[refuel] from sticks...")
        TurtleApi.refuel()
    end

    print("[condense] backpack...")
    TurtleApi.condense() -- need to condense because we are not selecting saplings in reverse order (which we should)
end

local function doWork()
    assert(isAtWork(), "expected to sit on top of dirt")

    if TurtleApi.probe("top", ItemApi.birchLog) then
        -- should only happen if turtle crashed while planting a tree
        TurtleApi.harvestBirchTree(32)
    end

    while shouldPlantTree() do
        if plantTree() then
            TurtleApi.select(1)
            TurtleApi.dig()
            TurtleApi.walk()
            TurtleApi.harvestBirchTree(32)
            refuelFromBackpack()
        else
            -- this case should only happen when bone meal ran out before sapling could be grown
            TurtleApi.dig()
            TurtleApi.walk()
            break
        end
    end

    print("[done] going home!")
end

local function recover()
    if isHome() then
        if isParked() then
            return
        elseif peripheral.getType("back") == ItemApi.furnace then
            return TurtleApi.turn("right")
        elseif TurtleApi.probe("front", ItemApi.furnace) then
            return TurtleApi.turn("left")
        end
    elseif isAtWork() then
        return
    else
        print("[boot] rebooted while not at home or work")

        if TurtleApi.probe("top", ItemApi.birchLog) then
            TurtleApi.harvestBirchTree(32)
        elseif isLookingAtTree() then
            TurtleApi.mine()
            TurtleApi.move()
        else
            while TurtleApi.tryMove("down") do
            end

            if TurtleApi.probe("bottom", {ItemApi.spruceFence, ItemApi.oakFence, ItemApi.stoneBrickWall}) then
                -- turtle crashed and landed on the one fence piece that directs it to the tree.
                -- should be safe to move back one, go down, and then resume default move routine
                TurtleApi.walk("back")
                TurtleApi.walk("down")
            end
        end
    end
end

EventLoop.run(function()
    RemoteService.run({"lumberjack"})
end, function()
    Utils.writeStartupFile("lumberjack")
    print(string.format("[lumberjack %s] booting...", version()))
    TurtleApi.setBreakable({ItemApi.birchLog, ItemApi.birchLeaves, ItemApi.birchSapling})
    recover()

    while true do
        if isParked() then
            doHomework()
            TurtleApi.turn("left")
            TurtleApi.move()
        elseif isAtWork() then
            doWork()
            TurtleApi.turn("left")
            TurtleApi.walk()
        else
            while not TurtleApi.tryWalk() do
                local block = TurtleApi.probe()

                if not block then
                    error("could not move even though front seems to be free")
                end

                if isLookingAtTree() then
                    -- should only happen if sapling got placed by player
                    TurtleApi.mine()
                else
                    TurtleApi.turn(getBlockTurnSide(block))
                end
            end
        end
    end
end)
