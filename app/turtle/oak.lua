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
local Rpc = require "lib.tools.rpc"
local Inventory = require "lib.apis.inventory.inventory-api"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local OakService = require "lib.systems.farms.oak-service"

print(string.format("[oak %s] booting...", version()))

local minFuel = 80 * 65;

local function isHome()
    return TurtleApi.probe("bottom", "minecraft:barrel") ~= nil
end

local function isHarvesting()
    return TurtleApi.probe("top", "minecraft:oak_log") ~= nil
end

local function harvest()
    print("[harvest] gettin' logs!")
    while TurtleApi.probe("top", "minecraft:oak_log") do
        TurtleApi.move("up")
    end

    while TurtleApi.tryWalk("down") do
    end
end

local function shouldPlantTree()
    local stock = TurtleApi.getStock()
    local needsMoreLogs = (stock["minecraft:oak_log"] or 0) < 64
    local hasBoneMeal = (stock["minecraft:bone_meal"] or 0) >= 32
    local hasSaplings = (stock["minecraft:oak_sapling"] or 0) > 0

    return OakService.isOn() and hasSaplings and needsMoreLogs and hasBoneMeal
end

local function plantTree()
    if TurtleApi.probe("front", "minecraft:oak_log") then
        return true
    end

    print("[plant] tree...")
    TurtleApi.put("front", "minecraft:oak_sapling")

    while TurtleApi.selectItem("minecraft:bone_meal") and TurtleApi.place() do
    end

    -- when player harvests the leafs they can easily break the sapling. in that case, suck it in
    while TurtleApi.suck() do
    end

    return TurtleApi.probe("front", "minecraft:birch_log")
end

-- [todo] copied from lumberjack
---@param stash string
local function refuel(stash)
    -- [todo] turtle does not make sure to reach min fuel, it happened to me on MP server that
    -- a turtle ran out of fuel while working
    if not TurtleApi.hasFuel(minFuel) then
        print(string.format("refueling %s more fuel", TurtleApi.missingFuel(minFuel)))
        TurtleApi.selectEmpty(1)

        for slot, stack in pairs(InventoryPeripheral.getStacks(stash)) do
            if stack.name == "minecraft:charcoal" then
                TurtleApi.suckSlot("bottom", slot)
                TurtleApi.refuel(math.ceil(TurtleApi.missingFuel(minFuel) / 80))
            end

            if TurtleApi.hasFuel(minFuel) then
                break
            end
        end

        print("refueled to", turtle.getFuelLevel())

        -- in case we reached fuel limit and now have charcoal in the inventory
        if not TurtleApi.tryDump(stash) then
            error("stash full")
        end
    else
        print("[fuel] ok:", turtle.getFuelLevel())
    end
end

---@param stash string
local function loadUp(stash)
    for slot, item in pairs(InventoryPeripheral.getStacks(stash)) do
        if item.name == "minecraft:oak_sapling" or item.name == "minecraft:bone_meal" then
            TurtleApi.suckSlot(stash, slot)
        end
    end
end

-- [todo] copied & adapted from lumberjack
---@param stash string
---@param io string
local function doInputOutput(stash, io)
    print("[push] output...")
    TurtleApi.pushOutput(stash, io)
    print("[pull] input...")
    TurtleApi.pullInput(io, stash)

    local isOutputFull = function()
        return Inventory.getItemOpenCount({io}, "minecraft:oak_log", "output") == 0
    end

    if isOutputFull() then
        print("[waiting] for oak logs to drain")

        while isOutputFull() do
            os.sleep(3)
        end
    end

    local needsMoreBoneMeal = function()
        return Inventory.getItemCount({stash}, "minecraft:bone_meal", "buffer") < 32
    end

    if needsMoreBoneMeal() then
        print("[waiting] for more bone meal to arrive")

        while needsMoreBoneMeal() do
            os.sleep(3)
            TurtleApi.pullInput(io, stash)
        end
    end

    local needsMoreSaplings = function()
        return Inventory.getItemCount({stash}, "minecraft:oak_sapling", "buffer") < 1
    end

    if needsMoreSaplings() then
        print("[waiting] for more oak saplings to arrive")

        while needsMoreSaplings() do
            os.sleep(3)
            TurtleApi.pullInput(io, stash)
        end
    end

    local needsMoreFuel = function()
        local missingFuel = math.max(minFuel - TurtleApi.getNonInfiniteFuelLevel(), 0)

        if missingFuel == 0 then
            return false
        end

        return Inventory.getItemCount({stash}, "minecraft:charcoal", "buffer") < math.floor(missingFuel / 80)
    end

    if needsMoreFuel() then
        print("[waiting] for more charcoal to arrive")

        while needsMoreFuel() do
            os.sleep(3)
            TurtleApi.pullInput(io, stash)
        end
    end

    print("[ready] input looks good!")
end

local stash = "bottom"
local io = "left"

-- resume from crash
if isHarvesting() then
    harvest()
elseif not isHome() then
    while TurtleApi.tryWalk("down") do
    end
end

if TurtleApi.probe("bottom", "minecraft:dirt") then
    TurtleApi.move("back")
elseif TurtleApi.probe("front", "minecraft:chest") then
    TurtleApi.turn("right")
end

Utils.writeStartupFile("oak")

EventLoop.run(function()
    Rpc.host(OakService)
end, function()
    while true do
        if not TurtleApi.tryDump(stash) then
            error("stash is full :(")
        end

        doInputOutput(stash, io)

        if not OakService.isOn() then
            print("[off] turned off")

            while not OakService.isOn() do
                os.sleep(3)
            end

            print("[on] turned on!")
        end

        refuel(stash)
        loadUp(stash)

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

