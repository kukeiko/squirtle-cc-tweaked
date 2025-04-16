if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

package.path = package.path .. ";/app/turtle/?.lua"
local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local InventoryApi = require "lib.apis.inventory.inventory-api"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local RemoteService = require "lib.systems.runtime.remote-service"
local harvestTree = require "lumberjack.harvest-tree"
local doFurnaceWork = require "lumberjack.do-furnace-work"

local maxLogs = 64
local minBoneMealForPlanting = 1
local minBoneMealForWork = 64
local maxPulledBoneMeal = 64 * 3
local charcoalForRefuel = 64
local minSaplings = 32

---@param type string
---@return string
local function requirePeripheral(type)
    local p = peripheral.find(type)

    if not p then
        error("not found: " .. type)
    end

    return peripheral.getName(p)
end

---@param block Block
---@return string
local function getBlockTurnSide(block)
    if block.name == "minecraft:spruce_fence" then
        return "left"
    elseif block.name == "minecraft:oak_fence" then
        return "right"
    else
        return "left"
    end
end

local function isHome()
    return TurtleApi.probe("bottom", "minecraft:barrel") ~= nil
end

local function isParked()
    return isHome() and TurtleApi.probe("front", "minecraft:chest") ~= nil
end

local function isAtWork()
    return TurtleApi.probe("bottom", {"minecraft:dirt", "minecraft:grass_block"}) ~= nil
end

local function isLookingAtTree()
    return TurtleApi.probe("front", {"minecraft:birch_sapling", "minecraft:birch_log"})
end

local function faceHomeExit()
    for _ = 1, 4 do
        if peripheral.hasType("back", "minecraft:furnace") then
            return
        end

        TurtleApi.turn("left")
    end

    error("could not face exit: no furnace found")
end

---@param stash string
---@param io string
local function refuel(stash, io)
    local minFuel = charcoalForRefuel * 80;
    local saplingsInStash = InventoryPeripheral.getItemCount(stash, "minecraft:birch_sapling")
    local missingSaplingsInIO = InventoryApi.getItemOpenCount({io}, "minecraft:birch_sapling", "output")
    local saplingsForRefuel = math.max(0, saplingsInStash - (missingSaplingsInIO + minSaplings))

    if saplingsForRefuel > 0 then
        TurtleApi.suckItem(stash, "minecraft:birch_sapling", saplingsForRefuel)
        -- [todo] this is only refueling from currently selected slot, but what if we have more than one stack of saplings to refuel from?
        TurtleApi.refuel()
    end

    if not TurtleApi.hasFuel(minFuel) then
        print(string.format("[refuel] need %s more fuel", TurtleApi.missingFuel(minFuel)))
        TurtleApi.selectEmpty(1)
        TurtleApi.suckItem(stash, "minecraft:charcoal", charcoalForRefuel)
        TurtleApi.refuel()
        print("[refueled] to", turtle.getFuelLevel())

        if not TurtleApi.hasFuel(minFuel) then
            -- get player to help with refueling
            TurtleApi.refuelTo(minFuel)
        end

        -- in case we reached fuel limit and now have charcoal in the inventory
        if not TurtleApi.dump(stash) then
            error("stash full")
        end
    else
        print("[ready] have enough fuel:", turtle.getFuelLevel())
    end
end

---@param stash string
---@param io string
local function doInputOutput(stash, io)
    print("[push] output...")
    TurtleApi.pushOutput(stash, io, {["minecraft:birch_sapling"] = minSaplings})
    print("[pull] input...")
    TurtleApi.pullInput(io, stash, nil, {["minecraft:bone_meal"] = maxPulledBoneMeal})

    local isCharcoalFull = function()
        return InventoryApi.getItemOpenCount({io}, "minecraft:charcoal", "output") == 0
    end

    local isBirchLogsFull = function()
        return InventoryApi.getItemOpenCount({io}, "minecraft:birch_log", "output") == 0
    end

    if isCharcoalFull() and isBirchLogsFull() then
        print("[waiting] for output to drain...")

        while isCharcoalFull() and isBirchLogsFull() do
            os.sleep(3)
        end
    end

    print("[info] output wants more, want to work now!")

    local needsMoreBoneMeal = function()
        return InventoryPeripheral.getItemCount(stash, "minecraft:bone_meal") < minBoneMealForWork
    end

    if needsMoreBoneMeal() then
        print("[waiting] for more bone meal to arrive")

        while needsMoreBoneMeal() do
            os.sleep(3)
            TurtleApi.pullInput(io, stash)
        end
    end

    print("[ready] input looks good!")
end

---@param stash string
local function drainDropper(stash)
    repeat
        local totalItemStock = InventoryApi.getTotalItemCount({stash}, "buffer")
        redstone.setOutput("bottom", true)
        os.sleep(.25)
        redstone.setOutput("bottom", false)
    until InventoryApi.getTotalItemCount({stash}, "buffer") == totalItemStock
end

---@param stash string
---@param io string
---@param furnace string
local function doHomework(stash, io, furnace)
    print("[reached] home! dumping to stash...")

    if not TurtleApi.dump(stash) then
        error("stash is full :(")
    end

    doFurnaceWork(furnace, stash, io, charcoalForRefuel)
    refuel(stash, io)
    drainDropper(stash)
    doInputOutput(stash, io)

    while TurtleApi.suck(stash) do
    end

    local backpackStock = TurtleApi.getStock()

    if not backpackStock["minecraft:birch_sapling"] then
        error("out of birch saplings :(")
    end

    if not backpackStock["minecraft:bone_meal"] then
        error("out of bone meal :(")
    end
end

local function plantTree()
    print("planting tree...")
    TurtleApi.walk("back")
    TurtleApi.put("front", "minecraft:birch_sapling")

    while not TurtleApi.probe("front", "minecraft:birch_log") and TurtleApi.selectItem("minecraft:bone_meal") do
        TurtleApi.place()
    end

    return TurtleApi.probe("front", "minecraft:birch_log")
end

local function shouldPlantTree()
    local stock = TurtleApi.getStock()
    local needsMoreLogs = (stock["minecraft:birch_log"] or 0) < maxLogs
    local hasBoneMeal = (stock["minecraft:bone_meal"] or 0) >= minBoneMealForPlanting
    local hasSaplings = (stock["minecraft:birch_sapling"] or 0) > 0

    return hasSaplings and needsMoreLogs and hasBoneMeal
end

local function refuelFromBackpack()
    while TurtleApi.missingFuel() > 0 and TurtleApi.selectItem("minecraft:stick") do
        print("refueling from sticks...")
        TurtleApi.refuel()
    end

    -- local saplingStock = Squirtle.getStock()["minecraft:birch_sapling"] or 0

    -- print("refueling from saplings...")
    -- while Squirtle.missingFuel() > 0 and saplingStock > 64 do
    --     Squirtle.selectItem("minecraft:birch_sapling")
    --     Squirtle.refuel(saplingStock - 64)
    --     saplingStock = Squirtle.getStock()["minecraft:birch_sapling"] or 0
    -- end

    print("condensing backpack...")
    TurtleApi.condense() -- need to condense because we are not selecting saplings in reverse order (which we should)
end

local function doWork()
    print("doing work!")
    assert(isAtWork(), "expected to sit on top of dirt")

    if TurtleApi.probe("top", "minecraft:birch_log") then
        -- should only happen if turtle crashed while planting a tree
        harvestTree()
    end

    while shouldPlantTree() do
        if plantTree() then
            TurtleApi.select(1)
            TurtleApi.dig()
            TurtleApi.walk()
            harvestTree()
            refuelFromBackpack()
        else
            -- this case should only happen when bone meal ran out before sapling could be grown
            TurtleApi.dig()
            TurtleApi.walk()
            break
        end
    end

    print("work finished! going home")
end

local function main()
    print(string.format("[lumberjack %s] booting...", version()))
    TurtleApi.setBreakable({"minecraft:birch_log", "minecraft:birch_leaves", "minecraft:birch_sapling"})

    -- recover from an interrupted state
    if not isHome() and not isAtWork() then
        print("rebooted while not at home or work")

        if TurtleApi.probe("top", "minecraft:birch_log") then
            harvestTree()
        elseif isLookingAtTree() then
            TurtleApi.mine()
            TurtleApi.move()
        else
            while TurtleApi.tryMove("down") do
            end

            if TurtleApi.probe("bottom", {"minecraft:spruce_fence", "minecraft:oak_fence", "minecraft:stone_brick_wall"}) then
                -- turtle crashed and landed on the one fence piece that directs it to the tree.
                -- should be safe to move back one, go down, and then resume default move routine
                TurtleApi.walk("back")
                TurtleApi.walk("down")
            end
        end
    end

    while true do
        if isParked() then
            local stash = requirePeripheral("minecraft:barrel")
            local io = requirePeripheral("minecraft:chest")
            local furnace = requirePeripheral("minecraft:furnace")

            doHomework(stash, io, furnace)
            faceHomeExit()
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
end

EventLoop.run(function()
    RemoteService.run({"lumberjack"})
end, function()
    Utils.writeStartupFile("lumberjack")
    main()
end)

