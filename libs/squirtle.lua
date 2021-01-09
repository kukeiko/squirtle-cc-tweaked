package.path = package.path .. ";/libs/?.lua"

local Inventory = require "inventory"
local Monitor = require "monitor"
local MonitorModemProxy = require "monitor-modem-proxy"
local Peripheral = require "peripheral"
local Sides = require "sides"
local Turtle = require "turtle"
local Utils = require "utils"

local Squirtle = {hasPickaxe = false}

function Squirtle.requireItem(name)
    local slot = Inventory.find(name)

    while not slot do
        print("[help] " .. name .. " is required - please put one into my inventory, then hit enter")
        Utils.waitForUserToHitEnter()
        slot = Inventory.find(name)
    end

    return slot
end

function Squirtle.hasAnyPeripheralEquipped()
    local sides = {"left", "right"}

    for i = 1, #sides do
        local side = sides[i]
        local type = Peripheral.getType(side)

        if type == "workbench" then
            return true
        elseif type == "modem" and Peripheral.call(side, "isWireless") then
            return true
        end
    end

    return false
end

function Squirtle.getEquippedPeripherals()
    local sides = {"left", "right"}
    local peripherals = {}

    for i = 1, #sides do
        local side = sides[i]
        local type = Peripheral.getType(side)

        if type == "workbench" then
            peripherals[side] = Peripheral.wrap(side)
        elseif type == "modem" and Peripheral.call(side, "isWireless") then
            peripherals[side] = Peripheral.wrap(side)
        end
    end

    return peripherals
end

function Squirtle.requirePickaxe()
    if not Squirtle.hasPickaxe then
        while not Inventory.selectFirstEmptySlot() do
            print("[help] my inventory is full - please take out at least one stack, then hit enter")
            Utils.waitForUserToHitEnter()
        end

        Turtle.equipLeft()
        local slot = Squirtle.requireItem("diamond_pickaxe")
        Turtle.select(slot)
        Turtle.equipLeft()
        Squirtle.hasPickaxe = true

        -- [todo] workaround for https://github.com/SquidDev-CC/CC-Tweaked/issues/660
        turtle.turnLeft()
        turtle.turnRight()
    end

    return true
end

--- old stuff

function Squirtle.openStash_old()
    local stash, side = Peripheral.wrapOne({"minecraft:barrel"})

    return stash, side
end

function Squirtle.requireEmptySlot()
    -- options = options or {input = true, stash = true, discard = true}

    local firstEmptySlot = Inventory.firstEmptySlot()

    if firstEmptySlot then
        return firstEmptySlot
    end

    -- first try compacting the inventory
    if not firstEmptySlot then
        print("condense...")
        Inventory.condense()
        firstEmptySlot = Inventory.firstEmptySlot()

        if firstEmptySlot then
            print("empty slot via condense")
            return firstEmptySlot
        end
    end

    error("no empty slot available")
end

function Squirtle.getLocalPeripherals()
    local available = {
        top = Peripheral.getType("top"),
        bottom = Peripheral.getType("bottom"),
        front = Peripheral.getType("front"),
        back = Peripheral.getType("back")
    }

    if Squirtle.hasAnyPeripheralEquipped() then
        Turtle.turnLeft()
        available.left = Peripheral.getType("front")
        available.right = Peripheral.getType("back")
        Turtle.turnRight()
    else
        available.left = Peripheral.getType("left")
        available.right = Peripheral.getType("right")
    end

    return available
end

function Squirtle.findSideOfLocalPeripheral(types)
    local available = Squirtle.getLocalPeripherals()

    for side, pType in pairs(available) do
        for i = 1, #types do
            if types[i] == pType then
                return side
            end
        end
    end
end

function Squirtle.firstEmptySlotInItems(table, size)
    for index = 1, size do
        if table[index] == nil then
            return index
        end
    end
end

function Squirtle.emptySlotsInItems(items, size)
    local emptySlots = {}

    for slot = 1, size do
        if items[slot] == nil then
            table.insert(emptySlots, slot)
        end
    end

    return emptySlots
end

function Squirtle.suckSlotFromContainer(side, slot, count)
    if slot == 1 then
        return Turtle.suck(side, count)
    end

    local container = peripheral.wrap(side)
    local items = container.list()

    if items[1] ~= nil then
        local firstEmptySlot = Squirtle.firstEmptySlotInItems(items, container.size())

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
            Inventory.selectFirstEmptySlot()
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

function Squirtle.wrapDefaultMonitor()
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

function Squirtle.printFuelLevelToMonitor(minFuel)
    local monitor = Squirtle.wrapDefaultMonitor()

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

return Squirtle
