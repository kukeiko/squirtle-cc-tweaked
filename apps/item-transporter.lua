package.path = package.path .. ";/libs/?.lua"

local FuelDictionary = require "fuel-dictionary"
local Inventory = require "inventory"
local Refueler = require "refueler"
local Squirtle = require "squirtle"
local Turtle = require "turtle"

local statePath = "/state/apps/item-transporter.state"

local function getDefaultState()
    return {isBufferOpen = false, isTransporting = false, fuelPerTrip = 100}
end

local function saveState(state)
    local file = fs.open(statePath, "w")
    file.write(textutils.serialize(state))
    file.close()
end

local function loadState()
    if not fs.exists(statePath) then
        saveState(getDefaultState())
    end

    local state = getDefaultState()
    local file = fs.open(statePath, "r")
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

local function navigateTunnel(checkEarlyExit)
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

local function findSideOfNearbyChest()
    local _, side = Squirtle.wrapPeripheral({"minecraft:chest"})

    return side
end

local function countItems(side)
    local items = peripheral.call(side, "list")
    local numItems = 0

    for _, item in pairs(items) do
        numItems = numItems + item.count
    end

    return numItems
end

local function refuelFromBuffer(bufferSide)
    if not Inventory.selectFirstEmptySlot() then
        error("inventory unexpectedly full")
    end

    local bufferStorage = peripheral.wrap(bufferSide)

    for _ = 1, bufferStorage.size() do
        if not turtle.suck() then
            break
        end

        turtle.refuel()

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

local function refuel(inputSide)
    -- print("[task] refueling (current: " .. turtle.getFuelLevel() .. ")")
    local bufferSide = "front"
    local inputChest = peripheral.wrap(inputSide)
    local missingFuel = Turtle.getMissingFuel()
    local slotsToConsume = {}

    -- collect the slots with fuel for consumption, and immediately push into the output
    -- any fuel we don't need so the next turtle can use it.
    for slot, item in pairs(inputChest.list()) do
        if FuelDictionary.isFuel(item.name) then
            local itemRefuelAmount = FuelDictionary.getRefuelAmount(item.name)

            if itemRefuelAmount < missingFuel then
                table.insert(slotsToConsume, slot)
                missingFuel = missingFuel - item.count * itemRefuelAmount
            else
                break
            end
        end
    end

    -- early exit - missing fuel after using items would stay the same
    if missingFuel == Turtle.getMissingFuel() then
        return 0
    end

    print("can refuel from " .. turtle.getFuelLevel() .. " to " .. turtle.getFuelLimit() -
              math.max(0, missingFuel))
    patchState({isBufferOpen = true})

    for i = 1, #slotsToConsume do
        if inputChest.pushItems(bufferSide, slotsToConsume[i]) == 0 then
            -- while this branch *could* be hit because input chest changed, we're not gonna assume that for simplicity's sake.
            -- instead we assume it happened because the buffer is full
            refuelFromBuffer(bufferSide)

            if inputChest.pushItems(bufferSide, slotsToConsume[i]) == 0 then
                error(
                    "could not push into buffer, which should've been empty because we just emptied it for refueling")
            end
        end
    end

    refuelFromBuffer(bufferSide)
    patchState({isBufferOpen = false})
    print("refueled to " .. turtle.getFuelLevel())
end

local function lookAtBuffer()
    for _ = 1, 4 do
        if peripheral.getType("front") ~= "minecraft:barrel" then
            turtle.turnLeft()
        else
            break
        end
    end

    return peripheral.getType("front") == "minecraft:barrel"
end

local function startup()
    local state = loadState()
    local bufferSide = "front"

    if not lookAtBuffer() then
        print("[startup] rebooted while not at home, trying to find it...")
        -- find home
        local outputChestSide = navigateTunnel(findSideOfNearbyChest)

        if not lookAtBuffer() then
            print("[startup] found the end instead, dumping inventory...")
            local dropSide = Turtle.faceSide(outputChestSide)
            
            while not Inventory.dumpTo(dropSide) do
                os.sleep(7)
            end

            -- we navigated to the end, dump and return back
            navigateTunnel(findSideOfNearbyChest)

            if not lookAtBuffer() then
                error("barrel is missing")
            end
        end
    end

    if state.isBufferOpen then
        print("got interrupted while buffer is open, refueling from it to clear it out...")
        refuelFromBuffer(bufferSide)
        patchState({isBufferOpen = false})
    end
end

local function unloadAnyOneItem()
    local inputChestSide = findSideOfNearbyChest()

    if inputChestSide then
        local dropSide, undoFacePeripheral = Turtle.facePeripheral(inputChestSide)

        for slot = 1, Inventory.size() do
            if turtle.getItemCount(slot) > 0 then
                turtle.select(slot)
                Turtle.drop(dropSide)

                if turtle.getItemCount(slot) == 0 then
                    undoFacePeripheral()
                    return true
                end
            end
        end
    end

    -- [todo] hardcoded
    if lookAtBuffer() then
        local bufferSide = "front"
        local buffer = peripheral.wrap(bufferSide)
        local emptyBufferSlots = Squirtle.emptySlotsInItems(buffer.list(), buffer.size())

        if #emptyBufferSlots > 1 then
            turtle.select(1)
            Turtle.drop(bufferSide)

            return true
        end
    end

    return false
end

local function ensureMinimalFuelLevel(minFuel)
    if turtle.getFuelLevel() >= math.max(minFuel, 0) then
        return
    end

    print("[refuel] need " .. minFuel - turtle.getFuelLevel() ..
              " more fuel to continue, trying to find some...")

    local refueled = Refueler.refuelFromInventory()

    if refueled > 0 and turtle.getFuelLevel() >= minFuel then
        print("[refuel] found enough fuel in the inventory")
        return
    elseif refueled > 0 and turtle.getFuelLevel() < minFuel then
        print("[refuel] refueled " .. refueled .. " from inventory, but it's not enough")
    end

    if not lookAtBuffer() then
        -- [todo] allow user to add fuel into inventory manually
        -- [todo] check input chest
        error("not enough fuel to continue. can't check barrel because i'm not next to it.")
    end

    if Inventory.isFull() and not unloadAnyOneItem() then
        -- [todo] allow user to add fuel into inventory manually
        error(
            "not enough fuel to continue, there might be some in input and/or buffer, but my inventory is full and i could not temporarily unload an item")
    end

    -- [todo] hardcoded
    local bufferSide = "front"
    -- [todo] should also always consume lava buckets cause it's an emergency (i.e. allow to consume more fuel than necessary)
    -- [todo] update todo above because it does it now (cause of the 1000)
    refueled = Refueler.refuelFromBuffer(bufferSide, minFuel, 1000)

    if refueled > 0 and turtle.getFuelLevel() >= minFuel then
        print("[refuel] found enough fuel in the buffer")
        return
    elseif refueled > 0 and turtle.getFuelLevel() < minFuel then
        print("[refuel] refueled " .. refueled .. " from buffer, but it's not enough")
    end

    local inputChestSide = findSideOfNearbyChest()

    if inputChestSide then
        refueled = Refueler.refuelFromInputUsingBuffer(inputChestSide, bufferSide, minFuel, 1000)

        if refueled > 0 and turtle.getFuelLevel() >= minFuel then
            print("[refuel] found enough fuel in the input")
            return
        elseif refueled > 0 and turtle.getFuelLevel() < minFuel then
            print("[refuel] refueled " .. refueled .. " from input, but it's not enough")
        end
    end
end

local function main(args)
    print("[item-transporter @ 2.1.0]")

    if args[1] == "run-on-startup" then
        local file = fs.open("startup/item-transporter.autorun.lua", "w")
        file.write("shell.run(\"item-transporter\")")
        file.close()
    end

    -- local fuelPerTrip = 100
    local fuelPerTrip = 20000

    startup()

    if not lookAtBuffer() then
        error("barrel is missing")
    end

    while (true) do
        local inputChestSide = findSideOfNearbyChest()

        if (not inputChestSide) then
            error("no nearby chest available")
        end

        -- [wip]
        Squirtle.printFuelLevelToMonitor(fuelPerTrip)
        ensureMinimalFuelLevel(fuelPerTrip)
        Squirtle.printFuelLevelToMonitor(fuelPerTrip)

        print("sleepy 3s")
        os.sleep(3)
    end

    -- while (true) do
    --     local inputChestSide = findSideOfNearbyChest()

    --     if (not inputChestSide) then
    --         error("no nearby chest available")
    --     end

    --     Squirtle.printFuelLevelToMonitor(fuelPerTrip)
    --     refuel(inputChestSide)
    --     Squirtle.printFuelLevelToMonitor(fuelPerTrip)

    --     local numInputItems = countItems(inputChestSide)
    --     os.sleep(3)

    --     if turtle.getFuelLevel() >= fuelPerTrip and numInputItems > 0 and numInputItems == countItems(inputChestSide) then
    --         print("no change in input for 3s, transporting items...")

    --         local suckSide = inputChestSide

    --         if Squirtle.tryTurn(inputChestSide) then
    --             suckSide = "front"
    --         end

    --         while Squirtle.suck(suckSide) do
    --         end

    --         print("[task] navigating tunnel to output chest")
    --         local fuelLevelBeforeTrip = turtle.getFuelLevel()
    --         local outputChestSide, outputChestSideError = navigateTunnel(findSideOfNearbyChest)

    --         if (not outputChestSide) then
    --             error(outputChestSideError)
    --         end

    --         local dropSide = outputChestSide

    --         if Squirtle.tryTurn(outputChestSide) then
    --             dropSide = "front"
    --         end

    --         print("[status] unloading...")
    --         Squirtle.dumpInventoryToOutput(dropSide)

    --         print("[status] unloaded as much as i could")
    --         print("[task] navigating tunnel to input chest")
    --         navigateTunnel(findSideOfNearbyChest)
    --         fuelPerTrip = fuelLevelBeforeTrip - turtle.getFuelLevel()
    --         print("fuel per trip:" .. fuelPerTrip)

    --         if not lookAtBuffer() then
    --             error("barrel is missing")
    --         end
    --     end
    -- end
end

main(arg)
