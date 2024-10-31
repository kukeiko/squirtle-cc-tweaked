if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

package.path = package.path .. ";/app/turtle/?.lua"
local Utils = require "lib.common.utils"
local EventLoop = require "lib.common.event-loop"
local Rpc = require "lib.common.rpc"
local Inventory = require "lib.inventory.inventory-api"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local Squirtle = require "lib.squirtle.squirtle-api"
local OakService = require "lib.features.oak-service"

print(string.format("[oak %s] booting...", version()))

local minFuel = 80 * 65;

local function isHome()
    return Squirtle.probe("bottom", "minecraft:barrel") ~= nil
end

local function isHarvesting()
    return Squirtle.probe("top", "minecraft:oak_log") ~= nil
end

local function harvest()
    print("[harvest] gettin' logs!")
    while Squirtle.probe("top", "minecraft:oak_log") do
        Squirtle.move("up")
    end

    while Squirtle.tryWalk("down") do
    end
end

local function shouldPlantTree()
    local stock = Squirtle.getStock()
    local needsMoreLogs = (stock["minecraft:oak_log"] or 0) < 64
    local hasBoneMeal = (stock["minecraft:bone_meal"] or 0) >= 32
    local hasSaplings = (stock["minecraft:oak_sapling"] or 0) > 0

    return OakService.isOn() and hasSaplings and needsMoreLogs and hasBoneMeal
end

local function plantTree()
    if Squirtle.probe("front", "minecraft:oak_log") then
        return true
    end

    print("[plant] tree...")
    Squirtle.put("front", "minecraft:oak_sapling")

    while Squirtle.selectItem("minecraft:bone_meal") and Squirtle.place() do
    end

    -- when player harvests the leafs they can easily break the sapling. in that case, suck it in
    while Squirtle.suck() do
    end

    return Squirtle.probe("front", "minecraft:birch_log")
end

-- [todo] copied from lumberjack
---@param stash string
local function refuel(stash)
    -- [todo] turtle does not make sure to reach min fuel, it happened to me on MP server that
    -- a turtle ran out of fuel while working
    if not Squirtle.hasFuel(minFuel) then
        print(string.format("refueling %s more fuel", Squirtle.missingFuel(minFuel)))
        Squirtle.selectEmpty(1)

        for slot, stack in pairs(InventoryPeripheral.getStacks(stash)) do
            if stack.name == "minecraft:charcoal" then
                Squirtle.suckSlot("bottom", slot)
                Squirtle.refuel(math.ceil(Squirtle.missingFuel(minFuel) / 80))
            end

            if Squirtle.hasFuel(minFuel) then
                break
            end
        end

        print("refueled to", turtle.getFuelLevel())

        -- in case we reached fuel limit and now have charcoal in the inventory
        if not Squirtle.dump(stash) then
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
            Squirtle.suckSlot(stash, slot)
        end
    end
end

-- [todo] copied & adapted from lumberjack
---@param stash string
---@param io string
local function doInputOutput(stash, io)
    print("[push] output...")
    Squirtle.pushOutput(stash, io)
    print("[pull] input...")
    Squirtle.pullInput(io, stash)

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
            Squirtle.pullInput(io, stash)
        end
    end

    local needsMoreSaplings = function()
        return Inventory.getItemCount({stash}, "minecraft:oak_sapling", "buffer") < 1
    end

    if needsMoreSaplings() then
        print("[waiting] for more oak saplings to arrive")

        while needsMoreSaplings() do
            os.sleep(3)
            Squirtle.pullInput(io, stash)
        end
    end

    local needsMoreFuel = function()
        local missingFuel = math.max(minFuel - Squirtle.getNonInfiniteFuelLevel(), 0)

        if missingFuel == 0 then
            return false
        end

        return Inventory.getItemCount({stash}, "minecraft:charcoal", "buffer") < math.floor(missingFuel / 80)
    end

    if needsMoreFuel() then
        print("[waiting] for more charcoal to arrive")

        while needsMoreFuel() do
            os.sleep(3)
            Squirtle.pullInput(io, stash)
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
    while Squirtle.tryWalk("down") do
    end
end

if Squirtle.probe("bottom", "minecraft:dirt") then
    Squirtle.move("back")
elseif Squirtle.probe("front", "minecraft:chest") then
    Squirtle.turn("right")
end

Utils.writeStartupFile("oak")

EventLoop.run(function()
    Rpc.host(OakService)
end, function()
    while true do
        if not Squirtle.dump(stash) then
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
                Squirtle.move()
                harvest()
                Squirtle.move("back")
            end
        end

        -- suck potentially dropped items
        Squirtle.suckAll()
        Squirtle.turn("left")
        Squirtle.move("up")
        Squirtle.suckAll()
        Squirtle.suckAll("down")
        Squirtle.move("down")
        Squirtle.turn("right")
    end
end)

