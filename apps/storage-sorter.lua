function suckFromInputChest(topOrBottom)
    if (topOrBottom == "bottom") then
        while (turtle.suckDown()) do end
    else
        while (turtle.suckUp()) do end
    end
end

function dropIntoOutputChest(topOrBottom)
    for slot = 1, 16 do
        turtle.select(slot)

        if (topOrBottom == "bottom") then
            turtle.dropUp()
        else
            turtle.dropDown()
        end
    end
end

function dropIntoStorageChest()
    local filterChest = peripheral.wrap("bottom")
    local filteredItems = filterChest.list()
    local slotsToDrop = {}

    for k, filteredItem in pairs(filteredItems) do
        for slot = 1, 16 do
            local candidate = turtle.getItemDetail(slot)

            if (candidate ~= nil and candidate.name == filteredItem.name) then table.insert(slotsToDrop, slot) end
        end
    end

    if (#slotsToDrop > 0) then
        turtle.turnLeft()
        for i = 1, #slotsToDrop do
            turtle.select(slotsToDrop[i])
            turtle.drop()
        end

        turtle.turnRight()
    end

end

function distributeItems()
    while (turtle.forward()) do
        local chest = peripheral.wrap("bottom")

        if (chest ~= nil and type(chest.getItemDetail) == "function") then dropIntoStorageChest() end
    end

    turtle.turnLeft()
    turtle.turnLeft()

    while (turtle.forward()) do end

    turtle.turnLeft()
    turtle.turnLeft()
end

function suckFromSide(side)
    if side == "top" then
        return turtle.suckUp()
    elseif side == "bottom" then
        return turtle.suckDown()
    else
        return turtle.suck()
    end
end

function printFuelLevelToMonitor(criticalFuelLevelPc)
    local monitor = peripheral.wrap("back")
    if not monitor then return end

    local text = string.format("Fuel: %3.2f %%", turtle.getFuelLevel() / turtle.getFuelLimit() * 100)
    local w, h = monitor.getSize()
    local y = math.ceil(h / 2)
    local x = math.ceil((w - #text) / 2);
    monitor.clear()
    monitor.setCursorPos(x, y)
    monitor.write(text)

    local lavaBucketsToFull = math.floor((turtle.getFuelLimit() - turtle.getFuelLevel()) / 1000);
    text = string.format("%d more buckets", lavaBucketsToFull)
    x = math.ceil((w - #text) / 2);
    monitor.setCursorPos(x, 5)
    monitor.write(text)

    if getFuelLevelPercent() < criticalFuelLevelPc then
        text = "*Critical*"
        x = math.ceil((w - #text) / 2);
        monitor.setCursorPos(x, 1)
        monitor.write(text)
        text = "Turtle needs Lava"
        x = math.ceil((w - #text) / 2);
        monitor.setCursorPos(x, 2)
        monitor.write(text)
    end
end

function getFuelLevelPercent()
    return turtle.getFuelLevel() / turtle.getFuelLimit() * 100
end

function findSlotOfItem(name)
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)

        if item and item.name == name then return slot end
    end
end

function refuelFromLava()
    while turtle.getFuelLimit() - turtle.getFuelLevel() > 1000 do
        local lavaBucketSlot = findSlotOfItem("minecraft:lava_bucket")

        if lavaBucketSlot then
            turtle.select(lavaBucketSlot)
            turtle.refuel()
        else
            return
        end
    end
end

function main(args)
    local minFuelPercent = 10
    local inputSide = args[1] or "top";
    print(inputSide)

    while (true) do
        printFuelLevelToMonitor(minFuelPercent)
        refuelFromLava()

        while getFuelLevelPercent() <= minFuelPercent do
            print("fuel critical - put lava buckets into turtle inventory, then hit ENTER")

            while true do
                local _, key = os.pullEvent("key")
                if (key == keys.enter) then break end
            end

            refuelFromLava()
            printFuelLevelToMonitor(minFuelPercent)
        end

        printFuelLevelToMonitor(minFuelPercent)
        print("fuel level OK")
        print("waiting for items in input chest...")
        while not suckFromSide(inputSide) do os.sleep(3) end
        print("found items, waiting 3s for more...")
        os.sleep(3)
        print("sorting items into storage")
        suckFromInputChest(inputSide)
        refuelFromLava()
        distributeItems()
        dropIntoOutputChest(inputSide)
    end
end

main(arg)
