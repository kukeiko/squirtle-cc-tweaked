package.path = package.path .. ";/libs/?.lua"

local Inventory = require "inventory"
local Monitor = require "monitor"
local MonitorModemProxy = require "monitor-modem-proxy"
local Sides = require "sides"
local Turtle = require "turtle"

local squirtle = {}

function squirtle.moveFirstSlotSomewhereElse()
    if turtle.getItemCount(1) == 0 then
        return true
    end

    turtle.select(1)

    local slot = squirtle.firstEmptySlot()

    if not slot then
        return false
    end

    turtle.transferTo(slot)
end

function squirtle.dumpInventoryToOutput(outputSide)
    for slot = 1, Inventory.numSlots() do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)

            while not Turtle.drop(outputSide) or turtle.getItemCount(slot) > 0 do
                print("[task] output full, waiting 7s...")
                os.sleep(7)
            end
        end
    end
end

function squirtle.wrapDefaultMonitor()
    local sides = Sides.all()

    for i = 1, #sides do
        if peripheral.getType(sides[i]) == "monitor" then
            return Monitor.new(peripheral.wrap(sides[i]))
        end
    end

    for i = 1, #sides do
        if peripheral.getType(sides[i]) == "modem" then
            local modem = peripheral.wrap(sides[i])
            local remoteNames = modem.getNamesRemote()

            for e = 1, #remoteNames do
                if (modem.getTypeRemote(remoteNames[e]) == "monitor") then
                    return MonitorModemProxy.new(remoteNames[e], modem)
                end
            end
        end
    end

    return false, "No nearby default monitor available"
end

---@param types table The type(s) of peripheral to wrap
---@param sides? table
function squirtle.wrapPeripheral(types, sides)
    sides = sides or Sides.all()

    for i = 1, #sides do
        local foundType = peripheral.getType(sides[i])

        if foundType ~= nil then
            for e = 1, #types do
                if foundType == types[e] then
                    return peripheral.wrap(sides[i]), sides[i], types[e]
                end
            end
        end
    end
end

---@param sides? table
function squirtle.wrapItemContainer(sides)
    sides = sides or Sides.all()

    for i = 1, #sides do
        local candidate = peripheral.wrap(sides[i])

        if candidate ~= nil and type(candidate.getItemDetail) == "function" then
            return peripheral.wrap(sides[i]), sides[i]
        end
    end
end

function squirtle.refuelUsingLocalLava()
    local emptyBucketSlot = nil

    while Turtle.getMissingFuel() > 1000 do
        local lavaBucketSlot = Inventory.find("minecraft:lava_bucket")

        if lavaBucketSlot then
            turtle.select(lavaBucketSlot)
            turtle.refuel()
            emptyBucketSlot = emptyBucketSlot or lavaBucketSlot
            turtle.transferTo(emptyBucketSlot)
        else
            return
        end
    end
end

function squirtle.waitForUserToHitEnter()
    while true do
        local _, key = os.pullEvent("key")
        if (key == keys.enter) then
            break
        end
    end
end

function squirtle.preTaskRefuelRoutine(minFuel)
    squirtle.printFuelLevelToMonitor(minFuel)
    squirtle.refuelUsingLocalLava()

    while turtle.getFuelLevel() < minFuel do
        print("[waiting] fuel critical - put lava buckets into turtle inventory, then hit enter")
        squirtle.waitForUserToHitEnter()
        squirtle.refuelUsingLocalLava()
        squirtle.printFuelLevelToMonitor(minFuel)
    end

    squirtle.printFuelLevelToMonitor(minFuel)
    print("[status] fuel level ok")
end

function squirtle.firstEmptySlot()
    for slot = 1, Inventory.numSlots() do
        if turtle.getItemCount(slot) == 0 then
            return slot
        end
    end

    return nil
end

function squirtle.selectFirstEmptySlot()
    local slot = squirtle.firstEmptySlot()

    if not slot then
        return false
    end

    turtle.select(slot)

    return slot
end

function squirtle.firstEmptySlotInItems(table, size)
    for index = 1, size do
        if table[index] == nil then
            return index
        end
    end
end

function squirtle.emptySlotsInItems(items, size)
    local emptySlots = {}

    for slot = 1, size do
        if items[slot] == nil then
            table.insert(emptySlots, slot)
        end
    end

    return emptySlots
end

function squirtle.suckSlotFromContainer(side, slot, count)
    if slot == 1 then
        return Turtle.suck(side, count)
    end

    local container = peripheral.wrap(side)
    local items = container.list()

    if items[1] ~= nil then
        local firstEmptySlot = squirtle.firstEmptySlotInItems(items, container.size())

        if not firstEmptySlot and Inventory.isFull() then
            -- [todo] add and use "unloadAnyOneItem()" method from item-transporter
            error("container full. turtle also full, so no temporary unloading possible.")
        elseif not firstEmptySlot then
            if count ~= nil and count ~= items[slot].count then
                -- [todo] we're not gonna have a slot free in the container
                error("not yet implemented: container would still be full even after moving slot")
            end

            print("temporarily load first container slot into turtle...")
            local initialSlot = turtle.getSelectedSlot()
            squirtle.selectFirstEmptySlot()
            Turtle.suck(side)
            container.pushItems(side, slot, count, 1)
            -- [todo] if we want to be super strict, we would have to move the
            -- item we just sucked in back to the first slot after sucking the requested item
            Turtle.drop(side)
            print("pushing back temporarily loaded item")
            turtle.select(initialSlot)
        else
            print("moving first slot to first empty slot")
            container.pushItems(side, 1, nil, firstEmptySlot)
            container.pushItems(side, slot, count, 1)
        end
    else
        container.pushItems(side, slot, count, 1)
    end

    return Turtle.suck()
end

function squirtle.selectFirstNonEmptySlot()
    for slot = 1, Inventory.numSlots() do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            return slot
        end
    end

    return false
end

function squirtle.printFuelLevelToMonitor(minFuel)
    local monitor = squirtle.wrapDefaultMonitor()

    if not monitor then
        return
    end

    local text =
        string.format("Fuel: %3.2f %%", turtle.getFuelLevel() / turtle.getFuelLimit() * 100)
    local w, h = monitor:getSize()
    local y = math.ceil(h / 2)
    local x = math.ceil((w - #text + 1) / 2);
    monitor:clear()
    monitor:setCursorPos(x, y)
    monitor:write(text)

    if turtle.getFuelLevel() < minFuel then
        text = "*Critical*"
        x = math.ceil((w - #text + 1) / 2);
        monitor:setCursorPos(x, 1)
        monitor:write(text)

        text = "Turtle needs Fuel"
        x = math.ceil((w - #text + 1) / 2);
        monitor:setCursorPos(x, 2)
        monitor:write(text)

        local requiredLavaBuckets = math.ceil((minFuel - turtle.getFuelLevel()) / 1000)

        if requiredLavaBuckets == 1 then
            text = string.format("%d more bucket", requiredLavaBuckets)
        else
            text = string.format("%d more buckets", requiredLavaBuckets)
        end

        x = math.ceil((w - #text + 1) / 2);
        monitor:setCursorPos(x, 5)
        monitor:write(text)
    end
end

return squirtle
