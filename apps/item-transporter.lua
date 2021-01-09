package.path = package.path .. ";/libs/?.lua"

local Home = require "home"
local Inventory = require "inventory"
local Navigator = require "navigator"
local Refueler = require "refueler"
local Sides = require "sides"
local Squirtle = require "squirtle"
local Turtle = require "turtle"
local Utils = require "utils"
local Workspace = require "workspace"

local function findSideOfChest()
    return Squirtle.findSideOfLocalPeripheral({"minecraft:chest"})
end

local function findSideOfBuffer()
    return Squirtle.findSideOfLocalPeripheral({"minecraft:barrel"})
end

---@return Home
local function findHome()
    local chestSide = findSideOfChest()

    if not chestSide then
        print("[startup] rebooted while not at home, trying to find it...")

        -- find home
        chestSide = Navigator.navigateTunnel(findSideOfChest)

        if not findSideOfBuffer() then
            print("[startup] found the end instead, dumping inventory...")
            local dropSide = Turtle.faceSide(chestSide)

            while not Inventory.dumpTo(dropSide) do
                os.sleep(7)
            end

            chestSide = Navigator.navigateTunnel(findSideOfChest)

            if not findSideOfBuffer() then
                error("could not find home :(")
            end
        end
    end

    local verticalBlock, verticalSide = Turtle.inspectNameDownOrUp()

    if not verticalBlock then
        error("no vertical block")
    end

    local barrelSide = findSideOfBuffer()
    local horizontalBlock = Turtle.inspectName("front")

    if Sides.isHorizontal(chestSide) then
        Turtle.faceSide(chestSide)
        horizontalBlock = "minecraft:chest"
    elseif Sides.isHorizontal(barrelSide) then
        Turtle.faceSide(barrelSide)
        horizontalBlock = "minecraft:barrel"
    elseif not horizontalBlock then
        for _ = 1, 4 do
            Turtle.turnLeft()
            horizontalBlock = Turtle.inspectName("front")

            if horizontalBlock then
                break
            end
        end

        if not horizontalBlock then
            error("no horizontal block")
        end
    end

    return Home.new(verticalBlock, verticalSide, horizontalBlock)
end

local function main(args)
    print("[item-transporter @ 3.0.0-dev]")

    if args[1] == "autorun" then
        Utils.writeAutorunFile({"item-transporter"})
    end

    local fuelPerTrip = 100
    local mobileWorkspace = Workspace.new()
    mobileWorkspace:setInventory()
    Refueler.requireFuelLevel(mobileWorkspace, fuelPerTrip)

    local home = findHome()
    home:park()

    local workspace = Workspace.new()
    workspace:setInventory()
    workspace:setInput(findSideOfChest(), "minecraft:chest")
    workspace:setBuffer(findSideOfBuffer(), "minecraft:barrel")

    local minFuel = fuelPerTrip * 2

    while true do
        Squirtle.printFuelLevelToMonitor(minFuel)
        Refueler.requireFuelLevel(workspace, minFuel)
        Squirtle.printFuelLevelToMonitor(minFuel)

        local input = workspace:wrapInput()
        local _, bufferSide = workspace:wrapBuffer()
        local lastTransferredAt = os.time() * 60 * 69

        while true do
            local inputItems = input.list()
            local transferredItems = false

            for slot in pairs(inputItems) do
                if input.pushItems(bufferSide, slot) == 0 then
                    break
                else
                    transferredItems = true
                end
            end

            if transferredItems then
                local suckSide, undoFaceBuffer = Turtle.faceSide(bufferSide)
                while Turtle.suck(suckSide) do
                end
                undoFaceBuffer()
                lastTransferredAt = os.time() * 60 * 60
            end

            Refueler.refuelFromInventory(workspace)
            Squirtle.printFuelLevelToMonitor(minFuel)

            if not Inventory.isEmpty() and (os.time() * 60 * 60) - lastTransferredAt >= 7 then
                break
            end

            os.sleep(7)
        end

        print("[task] navigating tunnel to output chest")
        local fuelLevelBeforeTrip = turtle.getFuelLevel()
        local outputChestSide, outputChestSideError = Navigator.navigateTunnel(findSideOfChest)

        if (not outputChestSide) then
            error(outputChestSideError)
        end

        print("[status] unloading...")
        local dropSide = Turtle.faceSide(outputChestSide)

        while not Inventory.dumpTo(dropSide) do
            print("[info] output full, waiting 7s...")
            os.sleep(7)
        end

        print("[status] unloaded as much as i could")
        print("[task] navigating tunnel to input chest")
        Navigator.navigateTunnel(findSideOfChest)
        fuelPerTrip = fuelLevelBeforeTrip - turtle.getFuelLevel()
        print("[info] fuel per trip:" .. fuelPerTrip)
        home:park()
    end
end

main(arg)
