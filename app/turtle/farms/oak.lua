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
local Rpc = require "lib.tools.rpc"
local ItemApi = require "lib.inventory.item-api"
local TurtleApi = require "lib.turtle.turtle-api"
local RemoteService = require "lib.system.remote-service"
local OakService = require "lib.farms.oak-service"

local minFuel = 80 * 64;

local function isHome()
    return TurtleApi.probe("bottom", ItemApi.barrel) ~= nil
end

local function isHarvesting()
    return TurtleApi.probe("top", ItemApi.oakLog) ~= nil
end

local function harvest()
    print("[harvest] gettin' logs!")
    while TurtleApi.probe("top", ItemApi.oakLog) do
        TurtleApi.move("up")
    end

    while TurtleApi.tryWalk("down") do
    end
end

local function shouldPlantTree()
    local stock = TurtleApi.getStock()
    local needsMoreLogs = (stock[ItemApi.oakLog] or 0) < 64
    local hasBoneMeal = (stock[ItemApi.boneMeal] or 0) >= 32
    local hasSaplings = (stock[ItemApi.oakSapling] or 0) > 0

    return OakService.isOn() and hasSaplings and needsMoreLogs and hasBoneMeal
end

local function plantTree()
    if TurtleApi.probe("front", ItemApi.oakLog) then
        return true
    end

    print("[plant] tree...")
    TurtleApi.put("front", ItemApi.oakSapling)

    while TurtleApi.use("forward", ItemApi.boneMeal) do
    end

    -- when player harvests the leafs they can easily break the sapling. in that case, suck it in
    while TurtleApi.suck() do
    end

    return TurtleApi.probe("front", ItemApi.oakLog)
end

local function recover()
    -- resume from crash
    if isHarvesting() then
        harvest()
    elseif not isHome() then
        while TurtleApi.tryWalk("down") do
        end
    end

    if TurtleApi.probe("bottom", ItemApi.dirt) then
        TurtleApi.move("back")
    elseif TurtleApi.probe("front", ItemApi.chest) then
        TurtleApi.turn("right")
    end
end

EventLoop.run(function()
    Rpc.host(OakService)
end, function()
    RemoteService.run({"oak"})
end, function()
    print(string.format("[oak %s] booting...", version()))
    Utils.writeStartupFile("oak")
    recover()

    while true do
        TurtleApi.turn("left")
        TurtleApi.doHomework({
            barrel = "bottom",
            ioChest = "front",
            minFuel = minFuel,
            input = {required = {[ItemApi.boneMeal] = 32, [ItemApi.oakSapling] = 1}}
        })

        if not OakService.isOn() then
            print("[off] turned off")

            while not OakService.isOn() do
                os.sleep(3)
            end

            print("[on] turned on!")
        end

        TurtleApi.turn("right")

        while shouldPlantTree() do
            if plantTree() then
                TurtleApi.move()
                harvest()
                TurtleApi.move("back")
            end
        end

        -- suck potentially dropped items
        TurtleApi.suckAll()
        TurtleApi.turn("left")
        TurtleApi.move("up")
        TurtleApi.suckAll()
        TurtleApi.suckAll("down")
        TurtleApi.move("down")
        TurtleApi.turn("right")
    end
end)

