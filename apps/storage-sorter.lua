package.path = package.path .. ";/libs/?.lua"

local Squirtle = require "squirtle"
local Sides = require "sides"

function dropIntoOutputChest(outputSide)
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)

            while not Squirtle.drop(outputSide) do
                os.sleep(7)
            end
        end
    end
end

function dropIntoStorageChest(side)
    local filterChest = peripheral.wrap(side)
    local filteredItems = filterChest.list()
    local slotsToDrop = {}

    for k, filteredItem in pairs(filteredItems) do
        for slot = 1, 16 do
            local candidate = turtle.getItemDetail(slot)

            if (candidate ~= nil and candidate.name == filteredItem.name) then
                table.insert(slotsToDrop, slot)
            end
        end
    end

    if (#slotsToDrop > 0) then
        local dropSide = side

        if Sides.isHorizontal(side) then
            Squirtle.turn(side)
            dropSide = "front"
        end

        for i = 1, #slotsToDrop do
            turtle.select(slotsToDrop[i])
            Squirtle.drop(dropSide)
        end

        if Sides.isHorizontal(side) then
            Squirtle.undoTurn(side)
        end
    end
end

function distributeItems()
    while turtle.forward() do
        local chest, outputSide = Squirtle.wrapChest({"left", "right"})

        if (chest ~= nil) then
            dropIntoStorageChest(outputSide)
        end
    end

    Squirtle.turn("back")

    while (turtle.forward()) do
    end

    Squirtle.turn("back")
end

function findSlotOfItem(name)
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)

        if item and item.name == name then
            return slot
        end
    end
end

function main(args)
    if args[2] == "run-on-startup" then
        local file = fs.open("startup/storage-sorter.autorun.lua", "w")
        file.write("shell.run(\"storage-sorter\", \"" .. args[1] .. "\")")
        file.close()
    end

    print("[storage-sorter @ 3.1.0]")
    local minFuelPercent = 50

    local vInputSide = nil
    local argInputSide = args[1]

    if argInputSide == "from-bottom" then
        vInputSide = "bottom"
    elseif argInputSide == "from-top" then
        vInputSide = "top"
    else
        error("invalid 1st argument: " .. argInputSide)
    end

    print("[status] input taken from " .. vInputSide)

    while (true) do
        Squirtle.preTaskRefuelRoutine(minFuelPercent)

        print("[waiting] checking input chest...")
        while not Squirtle.suck(vInputSide) do
            os.sleep(3)
        end
        print("[waiting] found items, waiting 3s for more...")
        os.sleep(3)

        while Squirtle.suck(vInputSide) do
        end

        Squirtle.refuelUsingLocalLava()
        Squirtle.printFuelLevelToMonitor(minFuelPercent)

        print("[task] sorting items into storage")
        distributeItems()
        dropIntoOutputChest(Sides.invert(vInputSide))
    end
end

main(arg)
