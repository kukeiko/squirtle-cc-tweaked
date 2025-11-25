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
local ItemApi = require "lib.inventory.item-api"
local RemoteService = require "lib.system.remote-service"
local TurtleApi = require "lib.turtle.turtle-api"

local minFuel = 512
local maxCropWaitDifference = 1
local maxCropWaitTime = (7 * 3) + 1

---@param side string
---@return integer
local function getCropsRemainingAge(side)
    local crops = TurtleApi.probe(side)

    if not crops then
        error(string.format("no block at %s", side))
    end

    return ItemApi.getCropsRemainingAge(crops)
end

---@param side string
---@param max? integer if supplied, only wait if age difference does not exceed max
---@param time? integer maximum amount of time to wait
---@return boolean ready if crops are ready
local function waitUntilCropsReady(side, max, time)
    while getCropsRemainingAge(side) > 0 and TurtleApi.use(side, ItemApi.boneMeal) do
    end

    local remainingAge = getCropsRemainingAge(side)

    if max and remainingAge > max then
        return false
    end

    if remainingAge > 0 then
        print("[wait] until crop is ready")
    end

    local waitUntilReady = function()
        while getCropsRemainingAge(side) > 0 do
            os.sleep(7)
        end
    end

    if time then
        return parallel.waitForAny(waitUntilReady, function()
            os.sleep(time)
        end) == 1
    else
        waitUntilReady()
    end

    return true
end

local function tryPlantAnything()
    for slot = 1, TurtleApi.size() do
        if TurtleApi.selectIfNotEmpty(slot) then
            if TurtleApi.place("down") then
                return
            end
        end
    end
end

---@param block Block
local function harvestCrops(block)
    if waitUntilCropsReady("bottom", maxCropWaitDifference, maxCropWaitTime) then
        local selectedSeed = TurtleApi.selectItem(ItemApi.getSeedsOfCrop(block.name))

        if not selectedSeed then
            TurtleApi.selectFirstEmpty()
        end

        TurtleApi.dig("down")

        if not TurtleApi.place("down") then
            tryPlantAnything()
        end
    end
end

---@param block Block?
local function doFieldWork(block)
    if block and ItemApi.isCropsBlock(block) then
        harvestCrops(block)
    elseif not block then
        TurtleApi.dig("down")
        tryPlantAnything()
    end
end

---@param block Block
local function getBlockTurnSide(block)
    if block.name == ItemApi.spruceFence then
        return "left"
    elseif block.name == ItemApi.oakFence then
        return "right"
    else
        error(string.format("unknown block %s", block.name))
    end
end

local function moveNext()
    while not TurtleApi.tryWalk() do
        local block = TurtleApi.probe()

        if not block then
            print("[stuck] could not move even though front seems to be free")

            while not block do
                os.sleep(1)
                block = TurtleApi.probe()
            end
        end

        TurtleApi.turn(getBlockTurnSide(block))
    end
end

local function compostSeeds()
    while TurtleApi.selectItem(ItemApi.wheatSeeds) or TurtleApi.selectItem(ItemApi.beetrootSeeds) do
        TurtleApi.drop("bottom")
    end
end

local function doHomework()
    print("[reached] home!")

    TurtleApi.doHomework({
        barrel = "bottom",
        ioChest = "front",
        minFuel = minFuel,
        drainDropper = "bottom",
        output = {ignoreIfFull = {ItemApi.poisonousPotato, ItemApi.wheatSeeds, ItemApi.beetrootSeeds}}
    })

    while TurtleApi.selectItem(ItemApi.poisonousPotato) do
        print("[discard] poisonous potatoes")
        TurtleApi.drop("up")
    end

    local stock = TurtleApi.getStock()

    if stock[ItemApi.wheatSeeds] or stock[ItemApi.beetrootSeeds] then
        print("[compost] got seeds to turn into bone meal!")
        TurtleApi.walk("back")
        if not TurtleApi.probe("down", ItemApi.composter) then
            print("[failed] no composter, going back to barrel")
            TurtleApi.walk("forward")
        else
            print("[composting] seeds...")
            compostSeeds()
            TurtleApi.walk("forward")
        end
    end

    print("[ready] with homework! going back to work...")
    TurtleApi.turn("left")
    waitUntilCropsReady("front", maxCropWaitDifference, maxCropWaitTime)
    TurtleApi.walk("up")
end

-- the only way for the turtle to find home is to find a chest at bottom,
-- at which point the turtle will move back and then down. it'll then
-- expect there to be a barrel - otherwise errors out.
-- this strict requirement makes it so that we never have to move down
-- a block to check if we reached home, which is gud.
EventLoop.run(function()
    RemoteService.run({"farmer"})
end, function()
    Utils.writeStartupFile("farmer")
    print(string.format("[farmer %s] booting...", version()))
    TurtleApi.setBreakable(ItemApi.isCropsBlock)

    while true do
        local block = TurtleApi.probe("bottom")

        if block and block.name == ItemApi.chest then
            -- sitting on top of the chest, back down to barrel
            TurtleApi.walk("back")
            TurtleApi.walk("down")
        else
            if block and block.name == ItemApi.barrel then
                doHomework()
            elseif block and block.name == ItemApi.spruceFence then
                TurtleApi.turn(getBlockTurnSide(block))
            elseif block and block.name == ItemApi.oakFence then
                TurtleApi.turn(getBlockTurnSide(block))
            else
                doFieldWork(block)
            end

            moveNext()
        end
    end
end)
