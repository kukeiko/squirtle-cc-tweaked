package.path = package.path .. ";/libs/?.lua"

local Squirtle = require "squirtle"

function navigateTunnel(checkEarlyExit)
    local forbidden

    while true do
        local strategy

        if turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif forbidden ~= "up" and turtle.up() then
            strategy = "up"
            forbidden = "down"
        elseif forbidden ~= "down" and turtle.down() then
            strategy = "down"
            forbidden = "up"
        elseif turtle.turnLeft() and turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif turtle.turnLeft() and forbidden ~= "back" and turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif turtle.turnLeft() and turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        else
            return true
        end

        if strategy == "forward" then
            while turtle.forward() do
            end
        elseif strategy == "up" then
            while turtle.up() do
            end
        elseif strategy == "down" then
            while turtle.down() do
            end
        end

        if checkEarlyExit ~= nil and checkEarlyExit() then
            return checkEarlyExit()
        end
    end
end

function useAsFuel(name)
    return name == "minecraft:lava_bucket" or name == "minecraft:bamboo"
end

function getItemRefuelAmount(name)
    if name == "minecraft:lava_bucket" then
        return 1000
    elseif name == "minecraft:bamboo" then
        return 2
    else
        return 0
    end
end

function findSideOfNearbyChest()
    local _, side = Squirtle.wrapPeripheral({"minecraft:chest"})

    return side
end

function countItems(side)
    local items = peripheral.call(side, "list")
    local numItems = 0

    for _, item in pairs(items) do
        numItems = numItems + item.count
    end

    return numItems
end

function refuelFromBuffer(bufferSide)
    if not Squirtle.selectFirstEmptySlot() then
        error("inventory unexpectedly full")
    end

    local bufferStorage = peripheral.wrap(bufferSide)

    for _ = 1, bufferStorage.size() do
        if not turtle.suck() then
            break
        end

        turtle.refuel()

        -- drop an empty bucket or leftover items into the output chest in case we refueled using lava
        if turtle.getItemCount() > 0 then
            local nextSlot = turtle.getSelectedSlot() + 1

            while nextSlot <= 16 and not turtle.transferTo(nextSlot) do
                nextSlot = nextSlot + 1
            end

            if turtle.getItemCount() > 0 then
                error("inventory full")
            end
        end
    end
end

function refuel(inputSide)
    print("[task] refueling (current: " .. turtle.getFuelLevel() .. ")")
    local bufferSide = "front"
    local inputChest = peripheral.wrap(inputSide)
    local missingFuel = Squirtle.getMissingFuel()
    local slotsToConsume = {}

    -- collect the slots with fuel for consumption, and immediately push into the output
    -- any fuel we don't need so the next turtle can use it.
    for slot, item in pairs(inputChest.list()) do
        if useAsFuel(item.name) then
            local itemRefuelAmount = getItemRefuelAmount(item.name)

            if itemRefuelAmount < missingFuel then
                table.insert(slotsToConsume, slot)
                missingFuel = missingFuel - item.count * itemRefuelAmount
            else
                break
            end
        end
    end

    -- early exit - missing fuel after using items would stay the same
    if missingFuel == Squirtle.getMissingFuel() then
        return 0
    end

    print("can refuel from " .. turtle.getFuelLevel() .. " to " .. turtle.getFuelLimit() - math.max(0, missingFuel))

    for i = 1, #slotsToConsume do
        if inputChest.pushItems(bufferSide, slotsToConsume[i]) == 0 then
            -- while this branch *could* be hit because input chest changed, we're not gonna assume that for simplicity's sake.
            -- instead we assume it happened because the buffer is full
            refuelFromBuffer(bufferSide)

            if inputChest.pushItems(bufferSide, slotsToConsume[i]) == 0 then
                error("could not push into buffer, which should've been empty because we just emptied it for refueling")
            end
        end
    end

    refuelFromBuffer(bufferSide)
    print("refueled to " .. turtle.getFuelLevel())
end

function lookAtBuffer()
    for _ = 1, 4 do
        if peripheral.getType("front") ~= "minecraft:barrel" then
            turtle.turnLeft()
        else
            break
        end
    end

    if peripheral.getType("front") ~= "minecraft:barrel" then
        error("barrel is missing")
    end
end

function main(args)
    print("[item-transporter @ 2.0.0]")

    if args[1] == "run-on-startup" then
        local file = fs.open("startup/item-transporter.autorun.lua", "w")
        file.write("shell.run(\"item-transporter\")")
        file.close()
    end

    local fuelPerTrip = 100
    lookAtBuffer()

    while (true) do
        local inputChestSide = findSideOfNearbyChest()

        if (not inputChestSide) then
            error("no nearby chest available")
        end

        Squirtle.printFuelLevelToMonitor(fuelPerTrip)
        refuel(inputChestSide)
        Squirtle.printFuelLevelToMonitor(fuelPerTrip)

        local numInputItems = countItems(inputChestSide)
        os.sleep(3)

        if turtle.getFuelLevel() >= fuelPerTrip and numInputItems > 0 and numInputItems == countItems(inputChestSide) then
            print("no change in input for 3s, transporting items...")

            local suckSide = inputChestSide

            if Squirtle.tryTurn(inputChestSide) then
                suckSide = "front"
            end

            while Squirtle.suck(suckSide) do
            end

            print("[task] navigating tunnel to output chest")
            local fuelLevelBeforeTrip = turtle.getFuelLevel()
            local outputChestSide, outputChestSideError = navigateTunnel(findSideOfNearbyChest)

            if (not outputChestSide) then
                error(outputChestSideError)
            end

            local dropSide = outputChestSide

            if Squirtle.tryTurn(outputChestSide) then
                dropSide = "front"
            end

            print("[status] unloading...")

            for slot = 1, 16 do
                if turtle.getItemCount(slot) > 0 then
                    turtle.select(slot)

                    while not Squirtle.drop(dropSide) do
                        os.sleep(7)
                    end
                end
            end

            print("[status] unloaded as much as i could")
            print("[task] navigating tunnel to input chest")
            navigateTunnel(findSideOfNearbyChest)
            fuelPerTrip = fuelLevelBeforeTrip - turtle.getFuelLevel()
            print("fuel per trip:" .. fuelPerTrip)
            lookAtBuffer()
        end
    end
end

main(arg)
