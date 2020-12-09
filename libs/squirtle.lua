package.path = package.path .. ";/libs/?.lua"

local Monitor = require "monitor"
local MonitorModemProxy = require "monitor-modem-proxy"
local squirtle = {}

function squirtle.getFuelLevelPercent()
    return turtle.getFuelLevel() / turtle.getFuelLimit() * 100
end

function squirtle.suck(side, count)
    if side == "top" then
        return turtle.suckUp(count)
    elseif side == "bottom" then
        return turtle.suckDown(count)
    else
        return turtle.suck(count)
    end
end

function squirtle.turn(side, times)
    local turnFn
    times = times or 1

    if side == "left" then
        turnFn = turtle.turnLeft
    elseif side == "right" then
        turnFn = turtle.turnRight
    else
        error("side " .. side .. " is not a valid side to turn to")
    end

    for _ = 1, times do
        turnFn()
    end
end

function squirtle.turnTo(side)
    if (side == "left") then
        return turtle.turnLeft()
    elseif (side == "right") then
        return turtle.turnRight()
    elseif (side == "back") then
        return squirtle.turn("left", 2)
    end
end

function squirtle.suck(side, count)
    if (side == "top") then
        return turtle.suckUp(count)
    elseif (side == "bottom") then
        return turtle.suckDown(count)
    else
        return turtle.suck(count)
    end
end

function squirtle.drop(side, count)
    if (side == "top") then
        return turtle.dropUp(count)
    elseif (side == "bottom") then
        return turtle.dropDown(count)
    else
        return turtle.drop(count)
    end
end

function squirtle.turnInverse(side, times)
    return squirtle.turn(squirtle.invertSide(side), times)
end

function squirtle.invertSide(side)
    if side == "left" then
        return "right"
    elseif side == "right" then
        return "left"
    elseif side == "top" then
        return "bottom"
    elseif side == "bottom" then
        return "top"
    elseif side == "front" then
        return "back"
    elseif side == "back" then
        return "front"
    else
        error(side .. " is not a valid side")
    end
end

function squirtle.wrapDefaultMonitor()
    local sides = {"back", "front", "left", "right", "top", "bottom"}

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

function squirtle.findSlotOfItem(name)
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)

        if item and item.name == name then
            return slot
        end
    end
end

function squirtle.getMissingFuel()
    return turtle.getFuelLimit() - turtle.getFuelLevel()
end

function squirtle.refuelUsingLocalLava()
    local emptyBucketSlot = nil

    while squirtle.getMissingFuel() > 1000 do
        local lavaBucketSlot = squirtle.findSlotOfItem("minecraft:lava_bucket")

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

function squirtle.printFuelLevelToMonitor(criticalFuelLevelPc)
    local monitor = squirtle.wrapDefaultMonitor()
    if not monitor then
        return
    end

    local text = string.format("Fuel: %3.2f %%", turtle.getFuelLevel() / turtle.getFuelLimit() * 100)
    local w, h = monitor:getSize()
    local y = math.ceil(h / 2)
    local x = math.ceil((w - #text + 1) / 2);
    monitor:clear()
    monitor:setCursorPos(x, y)
    monitor:write(text)

    local lavaBucketsToFull = math.floor((turtle.getFuelLimit() - turtle.getFuelLevel()) / 1000);
    text = string.format("%d more buckets", lavaBucketsToFull)
    x = math.ceil((w - #text + 1) / 2);
    monitor:setCursorPos(x, 5)
    monitor:write(text)

    if squirtle.getFuelLevelPercent() < criticalFuelLevelPc then
        text = "*Critical*"
        x = math.ceil((w - #text + 1) / 2);
        monitor:setCursorPos(x, 1)
        monitor:write(text)
        text = "Turtle needs Lava"
        x = math.ceil((w - #text + 1) / 2);
        monitor:setCursorPos(x, 2)
        monitor:write(text)
    end
end

return squirtle
