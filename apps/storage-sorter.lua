package.path = package.path .. ";/libs/?.lua"

local Squirtle = require "squirtle"
local Sides = require "sides"

function dropIntoOutputChest(outputSide)
    for slot = 1, Squirtle.numSlots() do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)

            while not Squirtle.drop(outputSide) do
                os.sleep(7)
            end
        end
    end
end

function dropIntoStorageChest(side)
    local filterChest = peripheral.wrap(side)
    local filteredItems = filterChest.list()
    local slotsToDrop = {}

    for k, filteredItem in pairs(filteredItems) do
        for slot = 1, Squirtle.numSlots() do
            local candidate = turtle.getItemDetail(slot)

            if (candidate ~= nil and candidate.name == filteredItem.name) then
                table.insert(slotsToDrop, slot)
            end
        end
    end

    if (#slotsToDrop > 0) then
        local dropSide = side

        if Sides.isHorizontal(side) then
            Squirtle.turn(side)
            dropSide = "front"
        end

        for i = 1, #slotsToDrop do
            turtle.select(slotsToDrop[i])
            Squirtle.drop(dropSide)
        end

        if Sides.isHorizontal(side) then
            Squirtle.undoTurn(side)
        end
    end
end

function writeStartupFile(argInputSide)
    local file = fs.open("startup/storage-sorter.autorun.lua", "w")
    file.write("shell.run(\"storage-sorter\", \"" .. argInputSide .. "\")")
    file.close()
end

function parseInputSide(argInputSide)
    if argInputSide == "from-bottom" then
        return "bottom"
    elseif argInputSide == "from-top" then
        return "top"
    else
        error("invalid input side argument: " .. argInputSide)
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

function refuelFromBuffer(bufferSide, outputSide)
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
            while not Squirtle.drop(outputSide) do
            end
        end
    end
end

function refuel(inputSide)
    Squirtle.refuelUsingLocalLava()
    print("[task] refueling (current: " .. turtle.getFuelLevel() .. ")")
    local outputSide = Sides.invert(inputSide)
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
                -- [note] we're not checking for failure here because we assume it'll fail only because the output chest is full,
                -- and it might have space available the next time we refuel, so passing on extra fuel should still work over time.
                inputChest.pushItems(Sides.invert(inputSide), slot)
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
            refuelFromBuffer(bufferSide, outputSide)

            if inputChest.pushItems(bufferSide, slotsToConsume[i]) == 0 then
                error("could not push into buffer, which should've been empty because we just emptied it for refueling")
            end
        end
    end

    refuelFromBuffer(bufferSide, outputSide)
    print("refueled to " .. turtle.getFuelLevel())
end

function countItems(side)
    local items = peripheral.call(side, "list")
    local numItems = 0

    for _, item in pairs(items) do
        numItems = numItems + item.count
    end

    return numItems
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
    print("[storage-sorter @ 4.0.0]")
    local argInputSide, argRunOnStartup = table.unpack(args)
    local vInputSide = parseInputSide(args[1])

    if argRunOnStartup == "run-on-startup" then
        writeStartupFile(argInputSide)
    end

    local fuelPerTrip = 100
    lookAtBuffer()

    while true do
        Squirtle.printFuelLevelToMonitor(fuelPerTrip)
        refuel(vInputSide)
        Squirtle.printFuelLevelToMonitor(fuelPerTrip)

        local numInputItems = countItems(vInputSide)
        os.sleep(3)

        local hasEnoughFuel = turtle.getFuelLevel() >= fuelPerTrip
        local chestHadNoChange = numInputItems == countItems(vInputSide)
        local percentFullChest = numInputItems / peripheral.call(vInputSide, "size")

        if hasEnoughFuel and numInputItems > 0 and (numInputItems == countItems(vInputSide) ) then
            print("no change in input for 3s, sorting items into storage...")

            -- [todo] it is possible we're sucking in fuel we haven't been able to forward
            -- to the next turtle during the refuel routine. figure out if that's bad or not.
            while Squirtle.suck(vInputSide) do
            end

            print("[task] sorting items into storage")
            Squirtle.turnAround()
            fuelPerTrip = 0

            while turtle.forward() do
                local chest, outputSide = Squirtle.wrapItemContainer({"left", "right"})

                if (chest ~= nil) then
                    dropIntoStorageChest(outputSide)
                end

                fuelPerTrip = fuelPerTrip + 1
            end

            -- go home
            Squirtle.turnAround()

            while turtle.forward() do
                fuelPerTrip = fuelPerTrip + 1
            end

            -- dump into output chest, blocking until turtle is empty
            for slot = 1, Squirtle.numSlots() do
                if turtle.getItemCount(slot) > 0 then
                    turtle.select(slot)

                    while not Squirtle.drop(Sides.invert(vInputSide)) do
                        os.sleep(7)
                    end
                end
            end
        end
    end
end

main(arg)
