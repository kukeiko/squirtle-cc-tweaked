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

function squirtle.wrapDefaultMonitor()
    local sides = {"back", "front", "left", "right", "top", "bottom"}

    for i = 1, #sides do if peripheral.getType(sides[i]) == "monitor" then return peripheral.wrap(sides[i]) end end

    return false, "No nearby default monitor available"
end

function squirtle.findSlotOfItem(name)
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)

        if item and item.name == name then return slot end
    end
end

function squirtle.getMissingFuel()
    return turtle.getFuelLimit() - turtle.getFuelLevel()
end

function squirtle.refuelUsingLocalLava()
    while squirtle.getMissingFuel() > 1000 do
        local lavaBucketSlot = squirtle.findSlotOfItem("minecraft:lava_bucket")

        if lavaBucketSlot then
            turtle.select(lavaBucketSlot)
            turtle.refuel()
        else
            return
        end
    end
end

function squirtle.printFuelLevelToMonitor(criticalFuelLevelPc)
    local monitor = squirtle.wrapDefaultMonitor()
    local text = string.format("Fuel: %3.2f %%", turtle.getFuelLevel() / turtle.getFuelLimit() * 100)
    local w, h = monitor.getSize()
    local y = math.ceil(h / 2)
    local x = math.ceil((w - #text + 1) / 2);
    monitor.clear()
    monitor.setCursorPos(x, y)
    monitor.write(text)

    local lavaBucketsToFull = math.floor((turtle.getFuelLimit() - turtle.getFuelLevel()) / 1000);
    text = string.format("%d more buckets", lavaBucketsToFull)
    x = math.ceil((w - #text + 1) / 2);
    monitor.setCursorPos(x, 5)
    monitor.write(text)

    if squirtle.getFuelLevelPercent() < criticalFuelLevelPc then
        text = "*Critical*"
        x = math.ceil((w - #text + 1) / 2);
        monitor.setCursorPos(x, 1)
        monitor.write(text)
        text = "Turtle needs Lava"
        x = math.ceil((w - #text + 1) / 2);
        monitor.setCursorPos(x, 2)
        monitor.write(text)
    end
end

return squirtle
