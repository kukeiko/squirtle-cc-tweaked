package.path = package.path .. ";/libs/?.lua"

local Monitor = require "monitor"
local MonitorModemProxy = require "monitor-modem-proxy"
local Sides = require "sides"
local squirtle = {}

function squirtle.getFuelLevelPercent()
    return turtle.getFuelLevel() / turtle.getFuelLimit() * 100
end

function squirtle.turnTo(side)
    if side == "left" or side == "right" or side == "back" then
        return squirtle.turn(side)
    end

    return false
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

function squirtle.turn(side)
    if (side == "left") then
        return turtle.turnLeft()
    elseif (side == "right") then
        return turtle.turnRight()
    elseif (side == "back") then
        local s, e = turtle.turnLeft()

        if not s then
            return e
        end

        return turtle.turnLeft()
    else
        error("Can only turn to left, right and back")
    end
end

function squirtle.suck(side, count)
    if side == "top" then
        return turtle.suckUp(count)
    elseif (side == "bottom") then
        return turtle.suckDown(count)
    elseif side == "front" or side == nil then
        return turtle.suck(count)
    else
        error("Can only suck from front, top or bottom")
    end
end

function squirtle.drop(side, count)
    if (side == "top") then
        return turtle.dropUp(count)
    elseif (side == "bottom") then
        return turtle.dropDown(count)
    elseif side == "front" or side == nil then
        return turtle.drop(count)
    else
        error("Can only drop in front, top or bottom")
    end
end

function squirtle.undoTurn(side)
    if side == "back" then
        return squirtle.turn(side)
    elseif side == "left" or side == "right" then
        return squirtle.turn(Sides.invert(side))
    else
        error("Can only unto left, right & back turns")
    end
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
function squirtle.wrapChest(sides)
    sides = sides or Sides.all()

    for i = 1, #sides do
        local candidate = peripheral.wrap(sides[i])

        if candidate ~= nil and type(candidate.getItemDetail) == "function" then
            return peripheral.wrap(sides[i]), sides[i]
        end
    end
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

function squirtle.preTaskRefuelRoutine(minFuelPercent)
    squirtle.printFuelLevelToMonitor(minFuelPercent)
    squirtle.refuelUsingLocalLava()

    while squirtle.getFuelLevelPercent() < minFuelPercent do
        print("[waiting] fuel critical - put lava buckets into turtle inventory, then hit enter")

        while true do
            local _, key = os.pullEvent("key")
            if (key == keys.enter) then
                break
            end
        end

        squirtle.refuelUsingLocalLava()
        squirtle.printFuelLevelToMonitor(minFuelPercent)
    end

    squirtle.printFuelLevelToMonitor(minFuelPercent)
    print("[status] fuel level ok")
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

    if squirtle.getFuelLevelPercent() < criticalFuelLevelPc then
        text = "*Critical*"
        x = math.ceil((w - #text + 1) / 2);
        monitor:setCursorPos(x, 1)
        monitor:write(text)

        text = "Turtle needs Lava"
        x = math.ceil((w - #text + 1) / 2);
        monitor:setCursorPos(x, 2)
        monitor:write(text)

        local requiredLavaBuckets = math.ceil(((criticalFuelLevelPc - squirtle.getFuelLevelPercent()) / 100) * (turtle.getFuelLimit() / 1000))

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
