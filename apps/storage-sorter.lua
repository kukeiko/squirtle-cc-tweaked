package.path = package.path .. ";/libs/?.lua"

local Squirtle = require "squirtle"
local Sides = require "sides"
local FuelDictionary = require "fuel-dictionary"
local Refueler = require "refueler"

local function writeStartupFile(argInputSide)
    local file = fs.open("startup/storage-sorter.autorun.lua", "w")
    file.write("shell.run(\"storage-sorter\", \"" .. argInputSide .. "\")")
    file.close()
end

local function parseInputSide(argInputSide)
    if argInputSide == "from-bottom" then
        return "bottom"
    elseif argInputSide == "from-top" then
        return "top"
    else
        error("invalid input side: " .. argInputSide)
    end
end

local function parseOptions(args)
    local options = {autorun = false, reset = false}

    for i = 1, #args do
        if options[args[i]] ~= nil then
            options[args[i]] = true
        end
    end

    return options
end

local function getDefaultState()
    return {isBufferOpen = false, isDistributing = false, fuelPerTrip = 100}
end

local function saveState(state)
    local file = fs.open("/apps/storage-sorter.state", "w")
    file.write(textutils.serialize(state))
    file.close()
end

local function loadState()
    if not fs.exists("/apps/storage-sorter.state") then
        saveState(getDefaultState())
    end

    local state = getDefaultState()
    local file = fs.open("/apps/storage-sorter.state", "r")
    local savedState = textutils.unserialize(file.readAll())
    file.close()

    for k, v in pairs(savedState) do
        state[k] = v
    end

    return state
end

local function patchState(patch)
    local state = loadState()

    for k, v in pairs(patch) do
        state[k] = v
    end

    saveState(state)
end

local function resetState()
    saveState(getDefaultState())
end

local function refuelFromBuffer(bufferSide, outputSide)
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

local function refuelFromInventory(outputSide)
    local refueled, remainingSlots = Refueler.refuelFromInventory()

    if refueled > 0 then
        print("refueled " .. refueled .. " from inventory")
    end

    for i = 1, #remainingSlots do
        turtle.select(remainingSlots[i])
        Squirtle.drop(outputSide)
    end
end

local function refuel(inputSide)
    local outputSide = Sides.invert(inputSide)
    local bufferSide = "front"
    local inputChest = peripheral.wrap(inputSide)
    local missingFuel = Squirtle.getMissingFuel()
    local slotsToConsume = {}

    -- collect the slots with fuel for consumption, and immediately push into the output
    -- any fuel we don't need so the next turtle can use it.
    for slot, item in pairs(inputChest.list()) do
        local itemRefuelAmount = FuelDictionary.getRefuelAmount(item.name)

        if itemRefuelAmount > 0 then
            if itemRefuelAmount < missingFuel then
                table.insert(slotsToConsume, slot)
                missingFuel = missingFuel - item.count * itemRefuelAmount
            else
                -- [note] we're not checking for failure here because we assume it'll fail only because the output chest is full,
                -- and it might have space available the next time we refuel, so passing on extra fuel should still work over time.
                inputChest.pushItems(outputSide, slot)
            end
        end
    end

    -- early exit - missing fuel after using items would stay the same
    if missingFuel == Squirtle.getMissingFuel() then
        return 0
    end

    print("refueling from " .. turtle.getFuelLevel() .. " to " .. turtle.getFuelLimit() - math.max(0, missingFuel) .. "...")
    patchState({isBufferOpen = true})

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
    patchState({isBufferOpen = false})
    print("refueled to " .. turtle.getFuelLevel())
end

local function getChestStats(side)
    local items = peripheral.call(side, "list")
    local numItems = 0
    local numStacks = 0

    for _, item in pairs(items) do
        numItems = numItems + item.count
        numStacks = numStacks + 1
    end

    return numItems, numStacks
end

local function lookAtBuffer()
    for _ = 1, 4 do
        if peripheral.getType("front") == "minecraft:barrel" then
            return true
        else
            turtle.turnLeft()
        end
    end

    if peripheral.getType("front") ~= "minecraft:barrel" then
        return false
    end
end

local function dropIntoStorageChest(side)
    local filterChest = peripheral.wrap(side)
    local numItemTypes = 0
    local itemsToDrop = {}
    local slotsToDrop = {}

    for _, filteredItem in pairs(filterChest.list()) do
        if not itemsToDrop[filteredItem.name] then
            numItemTypes = numItemTypes + 1
        end

        itemsToDrop[filteredItem.name] = true
    end

    for slot = 1, Squirtle.numSlots() do
        local candidate = turtle.getItemDetail(slot)

        if candidate ~= nil and itemsToDrop[candidate.name] then
            table.insert(slotsToDrop, slot)
        end
    end

    if (#slotsToDrop > 0) then
        Squirtle.turn(side)

        -- [todo]: break early if chest is full. need to be careful about chests that
        -- have more than one item type to sort in.
        for i = 1, #slotsToDrop do
            turtle.select(slotsToDrop[i])

            if not turtle.drop() and numItemTypes == 1 then
                -- we can break early because chest only accepts 1 type of item, so a failure in
                -- dropping items can only be because the chest is full
                break
            end
        end

        Squirtle.undoTurn(side)
    end

    turtle.select(1)
end

local function distribute()
    Squirtle.turnAround()
    local fuelPerTrip = 0

    while not Squirtle.isEmpty() and turtle.forward() do
        local chest, outputSide = Squirtle.wrapItemContainer({"left", "right"})

        if (chest ~= nil) then
            dropIntoStorageChest(outputSide)
        end

        fuelPerTrip = fuelPerTrip + 1
    end

    patchState({isDistributing = false})
    -- go home
    Squirtle.turnAround()

    while turtle.forward() do
        fuelPerTrip = fuelPerTrip + 1
    end

    return fuelPerTrip
end

local function dumpInventoryToOutput(outputSide)
    for slot = 1, Squirtle.numSlots() do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)

            while not Squirtle.drop(outputSide) do
                os.sleep(7)
            end
        end
    end
end

local function goHomeFromAnyState()
    if not lookAtBuffer() then
        -- either the player did not place a barrel for the turtle, or we're not at our starting position.
        -- we first assume that we're not at our starting position due to the chunk the turtle is in being unloaded during its trip.
        -- (chunk loaders won't help as they won't fix the case where all players leave the server)

        while not turtle.forward() do
            turtle.turnLeft()
        end

        while turtle.forward() do
        end

        if not lookAtBuffer() then
            Squirtle.turnAround()
            while turtle.forward() do
            end

            if not lookAtBuffer() then
                error("no barrel found")
            end
        end
    end
end

local function clearBuffer(bufferSide, outputSide)
    local buffer = peripheral.wrap(bufferSide)

    for slot = 1, buffer.size() do
        while buffer.getItemDetail(slot) ~= nil do
            buffer.pushItems(outputSide, slot)
            -- todo: unnecessarily slow for cases where push was successful
            os.sleep(1)
        end
    end
end

local function startup(inputSide, fuelPerTrip)
    goHomeFromAnyState()
    Squirtle.printFuelLevelToMonitor(fuelPerTrip)

    local state = loadState()
    local bufferSide = "front"
    local outputSide = Sides.invert(inputSide)

    if state.isBufferOpen then
        print("buffer corrupted. cleaning out...")
        clearBuffer(bufferSide, outputSide)
        patchState({isBufferOpen = false})
    end

    refuelFromInventory(outputSide)

    if not Squirtle.isEmpty() then
        if state.isDistributing then
            print("i was interrupted while distributing cargo")

            while turtle.getFuelLevel() < fuelPerTrip do
                print("not enough fuel - put fuel into inventory, then hit enter")
                Squirtle.waitForUserToHitEnter()
                refuelFromInventory()
            end

            distribute()
        else
            print("i was interrupted while dumping to output")
            dumpInventoryToOutput(outputSide)
        end
    end
end

local function main(args)
    print("[storage-sorter @ 4.1.0]")

    -- todo: consolidate parsing into 1 method
    local argInputSide = args[1]
    local inputSide = parseInputSide(argInputSide)
    local options = parseOptions(args)

    if options.autorun then
        writeStartupFile(argInputSide)
    end

    if options.reset then
        resetState()
    end

    local state = loadState()
    local fuelPerTrip = state.fuelPerTrip

    startup(inputSide, fuelPerTrip)

    while true do
        Squirtle.printFuelLevelToMonitor(fuelPerTrip)
        refuel(inputSide)
        Squirtle.printFuelLevelToMonitor(fuelPerTrip)

        local numInputItems, numInputStacks = getChestStats(inputSide)
        os.sleep(3)

        local hasEnoughFuel = turtle.getFuelLevel() >= fuelPerTrip
        local chestHadNoChange = numInputItems == getChestStats(inputSide)
        local hasFullTurtleLoad = numInputStacks >= Squirtle.numEmptySlots()

        if hasEnoughFuel and numInputItems > 0 and (chestHadNoChange or hasFullTurtleLoad) then
            if chestHadNoChange then
                print("no change for 3s")
            elseif hasFullTurtleLoad then
                print("chest has more than i can carry")
            end

            print("sorting items into storage...")
            patchState({isDistributing = true})

            -- [todo] it is possible we're sucking in fuel we haven't been able to forward
            -- to the next turtle during the refuel routine. figure out if that's bad or not.
            while Squirtle.suck(inputSide) do
            end

            fuelPerTrip = distribute()
            patchState({fuelPerTrip = fuelPerTrip})

            print("pushing remaining into output chest...")
            dumpInventoryToOutput(Sides.invert(inputSide))

            print("checking input chest...")
        end
    end
end

main(arg)
