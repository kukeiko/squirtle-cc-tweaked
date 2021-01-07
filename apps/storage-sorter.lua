package.path = package.path .. ";/libs/?.lua"

local FuelDictionary = require "fuel-dictionary"
local Inventory = require "inventory"
local Peripheral = require "peripheral"
local Refueler = require "refueler"
local Sides = require "sides"
local Squirtle = require "squirtle"
local Turtle = require "turtle"

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
    if not Inventory.selectFirstEmptySlot() then
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
            while not Turtle.drop(outputSide) do
            end
        end
    end
end

local function refuelFromInventory(outputSide)
    local refueled, remainingSlots = Refueler.refuelFromInventory()

    if refueled > 0 then
        print("[refuel] refueled " .. refueled .. " from inventory")
    end

    for i = 1, #remainingSlots do
        turtle.select(remainingSlots[i])
        Turtle.drop(outputSide)
    end
end

local function refuel(inputSide)
    local outputSide = Sides.invert(inputSide)
    local bufferSide = "front"
    local inputChest = peripheral.wrap(inputSide)
    local missingFuel = Turtle.getMissingFuel()
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
    if missingFuel == Turtle.getMissingFuel() then
        return 0
    end

    print("[refuel] trying to refuel from " .. turtle.getFuelLevel() .. " to " ..
              turtle.getFuelLimit() - math.max(0, missingFuel) .. "...")
    patchState({isBufferOpen = true})

    for i = 1, #slotsToConsume do
        if inputChest.pushItems(bufferSide, slotsToConsume[i]) == 0 then
            -- while this branch *could* be hit because input chest changed, we're not gonna assume that for simplicity's sake.
            -- instead we assume it happened because the buffer is full
            refuelFromBuffer(bufferSide, outputSide)

            if inputChest.pushItems(bufferSide, slotsToConsume[i]) == 0 then
                error(
                    "could not push into buffer, which should've been empty because we just emptied it for refueling")
            end
        end
    end

    refuelFromBuffer(bufferSide, outputSide)
    patchState({isBufferOpen = false})
    print("[refuel] refueled to " .. turtle.getFuelLevel())
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

    for slot = 1, Inventory.size() do
        local candidate = turtle.getItemDetail(slot)

        if candidate ~= nil and itemsToDrop[candidate.name] then
            table.insert(slotsToDrop, slot)
        end
    end

    if (#slotsToDrop > 0) then
        local dropSide, undoFaceStorage = Turtle.faceSide(side)

        -- [todo]: break early if chest is full. need to be careful about chests that
        -- have more than one item type to sort in.
        for i = 1, #slotsToDrop do
            turtle.select(slotsToDrop[i])

            if not Turtle.drop(dropSide) and numItemTypes == 1 then
                -- we can break early because chest only accepts 1 type of item, so a failure in
                -- dropping items can only be because the chest is full
                break
            end
        end

        undoFaceStorage()
    end

    turtle.select(1)
end

local function distribute()
    Turtle.turnAround()
    local fuelPerTrip = 0

    while not Inventory.isEmpty() and turtle.forward() do
        local chest, outputSide = Peripheral.wrapContainer({"left", "right"})

        if (chest ~= nil) then
            dropIntoStorageChest(outputSide)
        end

        fuelPerTrip = fuelPerTrip + 1
    end

    patchState({isDistributing = false})
    -- go home
    Turtle.turnAround()

    while turtle.forward() do
        fuelPerTrip = fuelPerTrip + 1
    end

    return fuelPerTrip
end

local function findHome()
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
            Turtle.turnAround()
            while turtle.forward() do
            end

            if not lookAtBuffer() then
                error("could not find home: no barrel found")
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
    findHome()
    Squirtle.printFuelLevelToMonitor(fuelPerTrip)

    local state = loadState()
    local bufferSide = "front"
    local outputSide = Sides.invert(inputSide)

    if state.isBufferOpen then
        print("[startup] buffer was open during reboot, clearing it out...")
        clearBuffer(bufferSide, outputSide)
        patchState({isBufferOpen = false})
    end

    refuelFromInventory(outputSide)

    if not Inventory.isEmpty() then
        if state.isDistributing then
            print("[startup] rebooted while sorting items into storage")

            while turtle.getFuelLevel() < fuelPerTrip do
                print("[startup] not enough fuel - put fuel into inventory, then hit enter")
                Squirtle.waitForUserToHitEnter()
                refuelFromInventory(outputSide)
            end

            print("[startup] distributing cargo...")
            distribute()
        else
            print("[startup] rebooted while dumping cargo to output")

            while not Inventory.dumpTo(outputSide) do
                os.sleep(7)
            end
        end
    end
end

local function main(args)
    print("[storage-sorter @ 4.2.0]")

    -- todo: consolidate parsing into 1 method
    local argInputSide = args[1]
    local inputSide = parseInputSide(argInputSide)
    local outputSide = Sides.invert(inputSide)
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
        local hasFullTurtleLoad = numInputStacks >= Inventory.availableSize()

        if hasEnoughFuel and numInputItems > 0 and (chestHadNoChange or hasFullTurtleLoad) then
            if chestHadNoChange then
                print("no change for 3s")
            elseif hasFullTurtleLoad then
                print("chest has more than i can carry")
            end

            print("[task] sorting items into storage...")
            patchState({isDistributing = true})

            -- [todo] protect against slow input feed
            while Turtle.suck(inputSide) do
            end

            -- [note] it's possible fuel got added to the input directly after we refueled from it.
            -- in that case, refuel from inventory once more so we quickly pass on extra fuel
            -- to the next turtle. we don't have to check for an empty inventory after this call
            -- (i.e. we only sucked in fuel) because distribute() checks for it already.
            refuelFromInventory(outputSide)

            fuelPerTrip = distribute()
            patchState({fuelPerTrip = fuelPerTrip})

            -- pass items we couldn't sort in to the next turtle

            while not Inventory.dumpTo(outputSide) do
                os.sleep(7)
            end

            print("[task] checking input chest...")
        end
    end
end

main(arg)
