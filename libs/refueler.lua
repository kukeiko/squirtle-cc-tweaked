package.path = package.path .. ";/libs/?.lua"

local FuelDictionary = require "fuel-dictionary"
local Inventory = require "inventory"
local Peripheral = require "peripheral"
local Squirtle = require "squirtle"
local Turtle = require "turtle"
local Utils = require "utils"

local Refueler = {}

---@param workspace Workspace
---@param fuelLevel integer
---@return boolean
function Refueler.requireFuelLevel(workspace, fuelLevel)
    if Turtle.hasFuel(fuelLevel) then
        return true
    end

    local openFuel = fuelLevel - Turtle.getFuelLevel()
    print("[refuel] need " .. openFuel .. " more fuel to continue, trying to find some...")

    local overflow = 1000

    print("[refuel] checking inventory...")
    openFuel = Refueler.refuelFromInventory(workspace, openFuel, overflow)

    if openFuel == 0 then
        print("[refuel] found enough fuel in the inventory")
        return true
    end

    print("[refuel] refueled some from inventory, need " .. openFuel .. " more ...")

    -- [todo] run input check and inventory check (where user adds fuel manually) in parallel
    if workspace.input and workspace.buffer then
        print("[refuel] checking input...")
        openFuel = Refueler.refuelFromInput(workspace, openFuel, overflow)

        if openFuel > 0 then
            print("[refuel] need " .. openFuel .. " more fuel, checking input every 7s...")
        end

        while openFuel > 0 do
            os.sleep(7)
            openFuel = Refueler.refuelFromInput(workspace, openFuel, overflow)
        end

        print("[refuel] found enough fuel via input")
    end

    while openFuel > 0 do
        print("[help] not enough fuel, need " .. openFuel ..
                  " more. put some into inventory, then hit enter.")
        Utils.waitForUserToHitEnter()
        openFuel = Refueler.refuelFromInventory(workspace, openFuel, overflow)
    end

    return false, "not enough fuel (need " .. openFuel .. " more)"
end

---@param workspace Workspace
---@param fuel integer|nil
---@param overflow integer|nil
---@return number
function Refueler.refuelFromInventory(workspace, fuel, overflow)
    fuel = fuel or Turtle.getMissingFuel()
    local fuelStacks = FuelDictionary.pickStacks(Inventory.list(), fuel, overflow)

    if fuelStacks == nil then
        return fuel
    end

    local emptyBucketSlot = Inventory.find("minecraft:bucket")
    local fuelAtStart = Turtle.getFuelLevel()

    for slot, stack in pairs(fuelStacks) do
        Turtle.select(slot)
        Turtle.refuel(stack.count)

        local remaining = Turtle.getItemDetail(slot)

        if remaining and remaining.name == "minecraft:bucket" then
            if emptyBucketSlot == nil then
                emptyBucketSlot = slot
            elseif not Turtle.transferTo(emptyBucketSlot) then
                emptyBucketSlot = slot
            end
        end
    end

    if emptyBucketSlot and workspace.output then
        local outputSide = workspace.output.side

        print("[refuel] dropping empty buckets to output...")
        local dropSide, undoFaceOutput = Turtle.faceSide(outputSide)

        while Inventory.select("minecraft:bucket") do
            Turtle.drop(dropSide)
        end

        undoFaceOutput()
    end

    return math.max(0, fuel - (Turtle.getFuelLevel() - fuelAtStart))
end

---@param workspace Workspace
---@param fuel number|nil
---@param overflow integer|nil
---@return integer
function Refueler.refuelFromBuffer(workspace, fuel, overflow)
    fuel = fuel or Turtle.getMissingFuel()
    local buffer = Peripheral.wrap(workspace.buffer.side)
    local fuelStacks = FuelDictionary.pickStacks(buffer.list(), fuel, overflow)

    if fuelStacks == nil then
        return fuel
    end

    local bufferSide = Peripheral.getName(buffer)
    local fuelAtStart = Turtle.getFuelLevel()
    local emptySlot = Squirtle.requireEmptySlot()
    Turtle.select(emptySlot)
    local suckSide, undoFaceBuffer = Turtle.faceSide(bufferSide)
    local openFuel = fuel

    for slot, stack in pairs(fuelStacks) do
        if not Squirtle.suckSlotFromContainer(suckSide, slot, stack.count) then
            undoFaceBuffer()
            openFuel = Refueler.refuelFromInventory(workspace, openFuel, overflow)
            Turtle.faceSide(bufferSide)
        end
    end

    undoFaceBuffer()
    openFuel = Refueler.refuelFromInventory(workspace, openFuel, overflow)

    return math.max(0, fuel - (Turtle.getFuelLevel() - fuelAtStart))
end

---@param workspace Workspace
---@param fuel integer|nil
---@param overflow integer|nil
---@return integer
function Refueler.refuelFromInput(workspace, fuel, overflow)
    fuel = fuel or Turtle.getMissingFuel()
    local input = Peripheral.wrap(workspace.input.side)
    local fuelStacks = FuelDictionary.pickStacks(input.list(), fuel, overflow)

    if fuelStacks == nil then
        return fuel
    end

    local fuelAtStart = Turtle.getFuelLevel()
    local openFuel = fuel
    local bufferSide = workspace.buffer.side

    for slot, stack in pairs(fuelStacks) do
        if input.pushItems(bufferSide, slot, stack.count) < stack.count then
            openFuel = Refueler.refuelFromBuffer(workspace, openFuel, overflow)
        end
    end

    openFuel = Refueler.refuelFromBuffer(workspace, openFuel, overflow)

    return math.max(0, fuel - (Turtle.getFuelLevel() - fuelAtStart))
end

---@param workspace Workspace
function Refueler.refuel(workspace)
    if workspace.inventory then
        Refueler.refuelFromInventory(workspace)
    end

    if workspace.buffer then
        Refueler.refuelFromBuffer(workspace)
    end

    if workspace.input then
        Refueler.refuelFromInput(workspace)
    end
end

---@param workspace Workspace
function Refueler.passFuelToOutput(workspace)
    if workspace.inventory then
        local stacksInInventory = FuelDictionary.filterStacks(Inventory.list())

        if stacksInInventory then
            local dropSide, undoFaceOutput = Turtle.faceSide(workspace.output.side)

            for slot in pairs(stacksInInventory) do
                Turtle.select(slot)
                Turtle.drop(dropSide)
            end

            undoFaceOutput()
        end
    end

    if workspace.input then
        local input = Peripheral.wrap(workspace.input.side)
        local stacksInInput = FuelDictionary.filterStacks(input.list())

        if stacksInInput then
            for slot in pairs(stacksInInput) do
                input.pushItems(workspace.output.side, slot)
            end
        end
    end

    if workspace.buffer then
        local buffer = Peripheral.wrap(workspace.buffer.side)
        local stacksInBuffer = FuelDictionary.filterStacks(buffer.list())

        if stacksInBuffer then
            for slot in pairs(stacksInBuffer) do
                buffer.pushItems(workspace.output.side, slot)
            end
        end
    end
end

return Refueler
