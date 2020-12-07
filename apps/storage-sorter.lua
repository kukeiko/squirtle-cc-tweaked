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
        local dropFn

        if (topOrBottom == "bottom") then
            dropFn = turtle.dropUp
        else
            dropFn = turtle.dropDown
        end

        while not dropFn() do
            os.sleep(7)
        end
    end
end

function dropIntoStorageChest(outputSide)
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
        squirtle.turn(outputSide)

        for i = 1, #slotsToDrop do
            turtle.select(slotsToDrop[i])
            turtle.drop()
        end

        squirtle.turnInverse(outputSide)
    end
end

function distributeItems(outputSide)
    while (turtle.forward()) do
        local chest = peripheral.wrap("bottom")

        -- todo: need common lib fn for identifying chests
        if (chest ~= nil and type(chest.getItemDetail) == "function") then dropIntoStorageChest(outputSide) end
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
    print("[storage-sorter @ 2.0.0]")
    local minFuelPercent = 50

    local inputSide = nil
    local argInputSide = args[1]

    if argInputSide == "from-bottom" then
        inputSide = "bottom"
    elseif argInputSide == "from-top" then
        inputSide = "top"
    else
        error("invalid 1st argument: " .. argInputSide)
    end

    local outputSide = nil
    local argOutputSide = args[2];

    if argOutputSide == "to-left" then
        outputSide = "left"
    elseif argOutputSide == "to-right" then
        outputSide = "right"
    else
        error("invalid 2nd argument: " .. argOutputSide)
    end

    print("[status] input taken from " .. inputSide)
    print("[status] output taken to " .. outputSide)

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
        squirtle.printFuelLevelToMonitor(minFuelPercent)
        print("[task] sorting items into storage")
        distributeItems(outputSide)
        dropIntoOutputChest(inputSide)
    end
end

main(arg)
