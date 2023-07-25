package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Chest = require "world.chest"
local Backpack = require "squirtle.backpack"
local turn = require "squirtle.turn"
local inspect = require "squirtle.inspect"
local move = require "squirtle.move"
local dig = require "squirtle.dig"
local place = require "squirtle.place"
local dump = require "squirtle.dump"
local pushOutput = require "squirtle.transfer.push-output"
local pullInput = require "squirtle.transfer.pull-input"
local suck = require "squirtle.suck"
local Fuel = require "squirtle.fuel"
local suckSlotFromChest = require "squirtle.transfer.suck-slot-from-chest"
local getStacks = require "inventory.get-stacks"

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
    return inspect("bottom", "minecraft:barrel") ~= nil
end

local function isAtWork()
    return inspect("bottom", {"minecraft:dirt", "minecraft:grass_block"}) ~= nil
end

local function isLookingAtTree()
    return inspect("front", {"minecraft:birch_sapling", "minecraft:birch_log"})
end

local function faceHomeExit()
    for _ = 1, 4 do
        if peripheral.hasType("back", "minecraft:furnace") then
            return
        end

        turn("left")
    end

    error("could not face exit: no furnace found")
end

---@param stash string
local function refuel(stash)
    if turtle.getFuelLevel() < (64 * 80) then
        print("refueling, have", turtle.getFuelLevel(), ", want " .. (64 * 80))
        Backpack.selectFirstEmptySlot()

        for slot, stack in pairs(getStacks(stash)) do
            if stack.name == "minecraft:charcoal" then
                suckSlotFromChest("bottom", slot)
                turtle.refuel() -- [todo] should provide count to not consume a whole stack
            end

            if turtle.getFuelLevel() >= (64 * 80) then
                break
            end
        end

        print("refueled to", turtle.getFuelLevel())

        -- in case we reached fuel limit and now have charcoal in the inventory
        if not dump(stash) then
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

    if not dump(stash) then
        error("stash is full :(")
    end

    doFurnaceWork(furnace, stash, io)
    refuel(stash)
    doInputOutput(stash, io)

    while suck(stash) do
    end

    local backpackStock = Backpack.getStock()

    if not backpackStock["minecraft:birch_sapling"] then
        error("out of birch saplings :(")
    end

    if not backpackStock["minecraft:bone_meal"] then
        error("out of bone meal :(")
    end
end

local function plantTree()
    print("planting tree...")
    move("back")
    Backpack.selectItem("minecraft:birch_sapling")
    place()

    while not inspect("front", "minecraft:birch_log") do
        if Backpack.selectItem("minecraft:bone_meal") then
            while place() do
            end
        else
            dig()
            move("front")
            return false, "out of bone meal"
        end
    end

    return true
end

local function shouldPlantTree()
    local stock = Backpack.getStock()
    local needsMoreLogs = (stock["minecraft:birch_log"] or 0) < maxLogs
    local hasBoneMeal = (stock["minecraft:bone_meal"] or 0) > minBonemeal
    local hasSaplings = (stock["minecraft:birch_sapling"] or 0) > 0

    return hasSaplings and needsMoreLogs and hasBoneMeal
end

local function refuelFromBackpack()
    while Fuel.getMissingFuel() > 0 and Backpack.selectItem("minecraft:stick") do
        print("refueling from sticks...")
        Fuel.refuel()
    end

    local saplingStock = Backpack.getItemStock("minecraft:birch_sapling")

    print("refueling from saplings...")
    while Fuel.getMissingFuel() > 0 and saplingStock > 64 do
        Backpack.selectItem("minecraft:birch_sapling")
        Fuel.refuel(saplingStock - 64)
        saplingStock = Backpack.getItemStock("minecraft:birch_sapling")
    end

    print("condensing backpack...")
    Backpack.condense() -- need to condense because we are not selecting saplings in reverse order (which we should)
end

local function doWork()
    print("doing work!")
    assert(isAtWork(), "expected to sit on top of dirt")

    if inspect("top", "minecraft:birch_log") then
        -- should only happen if turtle crashed while planting a tree
        harvestTree()
    end

    while shouldPlantTree() do
        if plantTree() then
            Backpack.selectSlot(1)
            dig()
            move()
            harvestTree()
            refuelFromBackpack()
        else
            -- this case should only happen when bone meal ran out before sapling could be grown
            move()
            break
        end
    end

    print("work finished! going home")
end

local function moveNext()
    while not move() do
        local block = inspect()

        if not block then
            error("could not move even though front seems to be free")
        end

        if isLookingAtTree() then
            -- [todo] hack - should only happen if sapling got placed by player
            dig("front")
        else
            turn(getBlockTurnSide(block))
        end
    end
end

local function boot()
    print("[lumberjack v1.2.2] booting...")

    if not isHome() and not isAtWork() then
        print("rebooted while not at home or work")
        if inspect("top", "minecraft:birch_log") then
            harvestTree()
        elseif isLookingAtTree() then
            dig("front")
        else
            while inspect("bottom", "minecraft:birch_leaves") do
                dig("bottom")
                move("bottom")
            end

            while move("bottom") do
            end

            if inspect("bottom", {"minecraft:spruce_fence", "minecraft:oak_fence"}) then
                -- turtle crashed and landed on the one fence piece that directs it to the tree.
                -- should be safe to move back one, go down, and then resume default move routine
                move("back")
                move("down")
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
            move()
        elseif isAtWork() then
            doWork()
            turn("left")
            move()
        else
            moveNext()
        end
    end
end

return main(arg)
