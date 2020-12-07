package.path = package.path .. ";/libs/?.lua"

local squirtle = require "squirtle"

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

function findSlotOfItem(name)
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)

        if item and item.name == name then return slot end
    end
end

function main(args)
    print("[storage-sorter @ 1.0.1]")
    local minFuelPercent = 50
    local inputSide = args[1] or "top";
    print("[status] input taken from " .. inputSide)

    while (true) do
        squirtle.printFuelLevelToMonitor(minFuelPercent)
        squirtle.refuelUsingLocalLava()

        while squirtle.getFuelLevelPercent() <= minFuelPercent do
            print("[waiting] fuel critical - put lava buckets into turtle inventory, then hit enter")

            while true do
                local _, key = os.pullEvent("key")
                if (key == keys.enter) then break end
            end

            squirtle.refuelUsingLocalLava()
            squirtle.printFuelLevelToMonitor(minFuelPercent)
        end

        squirtle.printFuelLevelToMonitor(minFuelPercent)
        print("[status] fuel level ok")
        print("[waiting] checking input chest...")
        while not squirtle.suck(inputSide) do os.sleep(3) end
        print("[waiting] found items, waiting 3s for more...")
        os.sleep(3)
        suckFromInputChest(inputSide)
        squirtle.refuelUsingLocalLava()
        print("[task] sorting items into storage")
        distributeItems()
        dropIntoOutputChest(inputSide)
    end
end

main(arg)
