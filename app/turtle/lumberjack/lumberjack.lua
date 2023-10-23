package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Chest = require "world.chest"
local pushOutput = require "squirtle.transfer.push-output"
local pullInput = require "squirtle.transfer.pull-input"
local Fuel = require "squirtle.fuel"
local suckSlotFromChest = require "squirtle.transfer.suck-slot-from-chest"
local getStacks = require "inventory.get-stacks"
local SquirtleV2 = require "squirtle.squirtle-v2"
local harvestTree = require "lumberjack.harvest-tree"
local doFurnaceWork = require "lumberjack.do-furnace-work"

local maxLogs = 64
local minBonemeal = 1

---@param block Block
---@return string
local function getBlockTurnSide(block)
    if block.name == "minecraft:spruce_fence" then
        return "left"
    elseif block.name == "minecraft:oak_fence" then
        return "right"
    else
        error("block" .. block.name .. " is not a block that tells me how to turn")
    end
end

local function isHome()
    return SquirtleV2.inspect("bottom", "minecraft:barrel") ~= nil
end

local function isAtWork()
    return SquirtleV2.inspect("bottom", {"minecraft:dirt", "minecraft:grass_block"}) ~= nil
end

local function isLookingAtTree()
    return SquirtleV2.inspect("front", {"minecraft:birch_sapling", "minecraft:birch_log"})
end

local function faceHomeExit()
    for _ = 1, 4 do
        if peripheral.hasType("back", "minecraft:furnace") then
            return
        end

        SquirtleV2.left()
    end

    error("could not face exit: no furnace found")
end

---@param stash string
local function refuel(stash)
    local minFuel = 80 * 65;

    if not SquirtleV2.hasFuel(minFuel) then
        print(string.format("refueling %s more fuel", SquirtleV2.missingFuel(minFuel)))
        SquirtleV2.selectEmpty(1)

        for slot, stack in pairs(getStacks(stash)) do
            if stack.name == "minecraft:charcoal" then
                suckSlotFromChest("bottom", slot)
                SquirtleV2.refuelSlot(math.ceil(SquirtleV2.missingFuel(minFuel) / 80))
            end

            if SquirtleV2.hasFuel(minFuel) then
                break
            end
        end

        print("refueled to", turtle.getFuelLevel())

        -- in case we reached fuel limit and now have charcoal in the inventory
        if not SquirtleV2.dump(stash) then
            error("stash full")
        end
    else
        print("have enough fuel:", turtle.getFuelLevel())
    end
end

---@param stash string
---@param io string
local function doInputOutput(stash, io)
    print("pushing output...")
    pushOutput(stash, io)
    print("pulling input...")
    pullInput(io, stash)

    local missingCharcoal = function()
        return (Chest.getOutputMissingStock(io)["minecraft:charcoal"] or 0)
    end

    if missingCharcoal() == 0 then
        print("waiting for output to drain...")
    end

    while missingCharcoal() == 0 do
        os.sleep(3)
    end

    print("output has space for charcoal, want to work now!")
    print("checking if we have enough input...")

    if Chest.getItemStock(stash, "minecraft:bone_meal") < 64 then
        print("waiting for more bone meal...")

        while Chest.getItemStock(stash, "minecraft:bone_meal") < 64 do
            os.sleep(3)
            pullInput(io, stash)
        end
    end

    print("input looks good!")
end

---@param stash string
---@param io string
---@param furnace string
local function doHomework(stash, io, furnace)
    print("i am home! dumping inventory to stash...")

    if not SquirtleV2.dump(stash) then
        error("stash is full :(")
    end

    doFurnaceWork(furnace, stash, io)
    refuel(stash)
    doInputOutput(stash, io)

    while SquirtleV2.suck(stash) do
    end

    local backpackStock = SquirtleV2.getStock()

    if not backpackStock["minecraft:birch_sapling"] then
        error("out of birch saplings :(")
    end

    if not backpackStock["minecraft:bone_meal"] then
        error("out of bone meal :(")
    end
end

local function plantTree()
    print("planting tree...")
    SquirtleV2.back()
    SquirtleV2.placeFront("minecraft:birch_sapling")

    while not SquirtleV2.inspect("front", "minecraft:birch_log") and SquirtleV2.has("minecraft:bone_meal") do
        SquirtleV2.placeFront("minecraft:bone_meal")
    end

    return SquirtleV2.inspect("front", "minecraft:birch_log")
end

local function shouldPlantTree()
    local stock = SquirtleV2.getStock()
    local needsMoreLogs = (stock["minecraft:birch_log"] or 0) < maxLogs
    local hasBoneMeal = (stock["minecraft:bone_meal"] or 0) >= minBonemeal
    local hasSaplings = (stock["minecraft:birch_sapling"] or 0) > 0

    return hasSaplings and needsMoreLogs and hasBoneMeal
end

local function refuelFromBackpack()
    while Fuel.getMissingFuel() > 0 and SquirtleV2.select("minecraft:stick") do
        print("refueling from sticks...")
        Fuel.refuel()
    end

    local saplingStock = SquirtleV2.getStock()["minecraft:birch_sapling"] or 0

    print("refueling from saplings...")
    while Fuel.getMissingFuel() > 0 and saplingStock > 64 do
        SquirtleV2.select("minecraft:birch_sapling")
        Fuel.refuel(saplingStock - 64)
        saplingStock = SquirtleV2.getStock()["minecraft:birch_sapling"] or 0
    end

    print("condensing backpack...")
    SquirtleV2.condense() -- need to condense because we are not selecting saplings in reverse order (which we should)
end

local function doWork()
    print("doing work!")
    assert(isAtWork(), "expected to sit on top of dirt")

    if SquirtleV2.inspect("top", "minecraft:birch_log") then
        -- should only happen if turtle crashed while planting a tree
        harvestTree()
    end

    while shouldPlantTree() do
        if plantTree() then
            SquirtleV2.select(1)
            SquirtleV2.forward()
            harvestTree()
            refuelFromBackpack()
        else
            -- this case should only happen when bone meal ran out before sapling could be grown
            SquirtleV2.forward()
            break
        end
    end

    print("work finished! going home")
end

local function moveNext()
    -- [todo] need to exclude logs from digging for tryForward to not dig an already grown tree
    while not SquirtleV2.tryForward() do
        local block = SquirtleV2.inspect()

        if not block then
            error("could not move even though front seems to be free")
        end

        if isLookingAtTree() then
            -- [todo] hack - should only happen if sapling got placed by player
            SquirtleV2.dig()
        else
            SquirtleV2.turn(getBlockTurnSide(block))
        end
    end
end

local function boot()
    print("[lumberjack v1.3.0] booting...")
    SquirtleV2.requireItems({["minecraft:birch_sapling"] = 1})
    SquirtleV2.setBreakable({"minecraft:birch_log", "minecraft:birch_leaves", "minecraft:birch_sapling"})

    if not isHome() and not isAtWork() then
        print("rebooted while not at home or work")

        if SquirtleV2.inspect("top", "minecraft:birch_log") then
            harvestTree()
        elseif isLookingAtTree() then
            SquirtleV2.dig()
        else
            while SquirtleV2.tryDown() do
            end

            if SquirtleV2.inspect("bottom", {"minecraft:spruce_fence", "minecraft:oak_fence"}) then
                -- turtle crashed and landed on the one fence piece that directs it to the tree.
                -- should be safe to move back one, go down, and then resume default move routine
                SquirtleV2.back()
                SquirtleV2.down()
            end
        end
    end
end

---@param type string
---@return string
local function requirePeripheral(type)
    local p = peripheral.find(type)

    if not p then
        error("not found: " .. type)
    end

    return peripheral.getName(p)
end

local function main(args)
    boot()

    while true do
        if isHome() then
            local stash = requirePeripheral("minecraft:barrel")
            local io = requirePeripheral("minecraft:chest")
            local furnace = requirePeripheral("minecraft:furnace")

            doHomework(stash, io, furnace)
            faceHomeExit()
            SquirtleV2.move()
        elseif isAtWork() then
            doWork()
            SquirtleV2.left()
            SquirtleV2.move()
        else
            moveNext()
        end
    end
end

return main(arg)
