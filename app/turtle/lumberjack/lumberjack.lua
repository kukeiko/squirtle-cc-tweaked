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
local Squirtle = require "lib.squirtle.squirtle-api"
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
    return Squirtle.probe("bottom", "minecraft:barrel") ~= nil
end

local function isParked()
    return isHome() and Squirtle.probe("front", "minecraft:chest") ~= nil
end

local function isAtWork()
    return Squirtle.probe("bottom", {"minecraft:dirt", "minecraft:grass_block"}) ~= nil
end

local function isLookingAtTree()
    return Squirtle.probe("front", {"minecraft:birch_sapling", "minecraft:birch_log"})
end

local function faceHomeExit()
    for _ = 1, 4 do
        if peripheral.hasType("back", "minecraft:furnace") then
            return
        end

        Squirtle.turn("left")
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
        Squirtle.suckItem(stash, "minecraft:birch_sapling", saplingsForRefuel)
        -- [todo] this is only refueling from currently selected slot, but what if we have more than one stack of saplings to refuel from?
        Squirtle.refuel()
    end

    if not Squirtle.hasFuel(minFuel) then
        print(string.format("[refuel] need %s more fuel", Squirtle.missingFuel(minFuel)))
        Squirtle.selectEmpty(1)
        Squirtle.suckItem(stash, "minecraft:charcoal", charcoalForRefuel)
        Squirtle.refuel()
        print("[refueled] to", turtle.getFuelLevel())

        if not Squirtle.hasFuel(minFuel) then
            -- get player to help with refueling
            Squirtle.refuelTo(minFuel)
        end

        -- in case we reached fuel limit and now have charcoal in the inventory
        if not Squirtle.dump(stash) then
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
    Squirtle.pushOutput(stash, io, {["minecraft:birch_sapling"] = minSaplings})
    print("[pull] input...")
    Squirtle.pullInput(io, stash, nil, {["minecraft:bone_meal"] = maxPulledBoneMeal})

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
            Squirtle.pullInput(io, stash)
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

    if not Squirtle.dump(stash) then
        error("stash is full :(")
    end

    doFurnaceWork(furnace, stash, io, charcoalForRefuel)
    refuel(stash, io)
    drainDropper(stash)
    doInputOutput(stash, io)

    while Squirtle.suck(stash) do
    end

    local backpackStock = Squirtle.getStock()

    if not backpackStock["minecraft:birch_sapling"] then
        error("out of birch saplings :(")
    end

    if not backpackStock["minecraft:bone_meal"] then
        error("out of bone meal :(")
    end
end

local function plantTree()
    print("planting tree...")
    Squirtle.walk("back")
    Squirtle.put("front", "minecraft:birch_sapling")

    while not Squirtle.probe("front", "minecraft:birch_log") and Squirtle.selectItem("minecraft:bone_meal") do
        Squirtle.place()
    end

    return Squirtle.probe("front", "minecraft:birch_log")
end

local function shouldPlantTree()
    local stock = Squirtle.getStock()
    local needsMoreLogs = (stock["minecraft:birch_log"] or 0) < maxLogs
    local hasBoneMeal = (stock["minecraft:bone_meal"] or 0) >= minBoneMealForPlanting
    local hasSaplings = (stock["minecraft:birch_sapling"] or 0) > 0

    return hasSaplings and needsMoreLogs and hasBoneMeal
end

local function refuelFromBackpack()
    while Squirtle.missingFuel() > 0 and Squirtle.selectItem("minecraft:stick") do
        print("refueling from sticks...")
        Squirtle.refuel()
    end

    -- local saplingStock = Squirtle.getStock()["minecraft:birch_sapling"] or 0

    -- print("refueling from saplings...")
    -- while Squirtle.missingFuel() > 0 and saplingStock > 64 do
    --     Squirtle.selectItem("minecraft:birch_sapling")
    --     Squirtle.refuel(saplingStock - 64)
    --     saplingStock = Squirtle.getStock()["minecraft:birch_sapling"] or 0
    -- end

    print("condensing backpack...")
    Squirtle.condense() -- need to condense because we are not selecting saplings in reverse order (which we should)
end

local function doWork()
    print("doing work!")
    assert(isAtWork(), "expected to sit on top of dirt")

    if Squirtle.probe("top", "minecraft:birch_log") then
        -- should only happen if turtle crashed while planting a tree
        harvestTree()
    end

    while shouldPlantTree() do
        if plantTree() then
            Squirtle.select(1)
            Squirtle.dig()
            Squirtle.walk()
            harvestTree()
            refuelFromBackpack()
        else
            -- this case should only happen when bone meal ran out before sapling could be grown
            Squirtle.dig()
            Squirtle.walk()
            break
        end
    end

    print("work finished! going home")
end

local function main()
    print(string.format("[lumberjack %s] booting...", version()))
    Squirtle.setBreakable({"minecraft:birch_log", "minecraft:birch_leaves", "minecraft:birch_sapling"})

    -- recover from an interrupted state
    if not isHome() and not isAtWork() then
        print("rebooted while not at home or work")

        if Squirtle.probe("top", "minecraft:birch_log") then
            harvestTree()
        elseif isLookingAtTree() then
            Squirtle.mine()
            Squirtle.move()
        else
            while Squirtle.tryMove("down") do
            end

            if Squirtle.probe("bottom", {"minecraft:spruce_fence", "minecraft:oak_fence", "minecraft:stone_brick_wall"}) then
                -- turtle crashed and landed on the one fence piece that directs it to the tree.
                -- should be safe to move back one, go down, and then resume default move routine
                Squirtle.walk("back")
                Squirtle.walk("down")
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
            Squirtle.move()
        elseif isAtWork() then
            doWork()
            Squirtle.turn("left")
            Squirtle.walk()
        else
            while not Squirtle.tryWalk() do
                local block = Squirtle.probe()

                if not block then
                    error("could not move even though front seems to be free")
                end

                if isLookingAtTree() then
                    -- should only happen if sapling got placed by player
                    Squirtle.mine()
                else
                    Squirtle.turn(getBlockTurnSide(block))
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

