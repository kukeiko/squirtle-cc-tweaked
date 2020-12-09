package.path = package.path .. ";/libs/?.lua"

local squirtle = require "squirtle"

function findSideOfNearbyChest()
    local sides = {"back", "front", "left", "right", "top", "bottom"}

    for i = 1, #sides do
        if peripheral.getType(sides[i]) == "minecraft:chest" then
            return sides[i]
        end
    end

    return false, "No nearby chest available"
end

function navigateTunnel()
    local forbidden

    while true do
        local strategy

        if turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif turtle.turnLeft() and turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif turtle.turnLeft() and forbidden ~= "back" and turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif turtle.turnLeft() and turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif forbidden ~= "up" and turtle.up() then
            strategy = "up"
            forbidden = "down"
        elseif forbidden ~= "down" and turtle.down() then
            strategy = "down"
            forbidden = "up"
        else
            return true
        end

        if strategy == "forward" then
            while turtle.forward() do
            end
        elseif strategy == "up" then
            while turtle.up() do
            end
        elseif strategy == "down" then
            while turtle.down() do
            end
        end
    end
end

function main()
    print("[item-transporter @ 1.1.0]")
    local minFuelPercent = 32

    while (true) do
        squirtle.printFuelLevelToMonitor(minFuelPercent)
        squirtle.refuelUsingLocalLava()

        while squirtle.getFuelLevelPercent() <= minFuelPercent do
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

        print("[waiting] checking input chest...")
        local inputChestSide, e = findSideOfNearbyChest()

        if (not inputChestSide) then
            error(e)
        end

        squirtle.turnTo(inputChestSide)

        while not squirtle.suck(inputChestSide) do
            os.sleep(3)
        end

        print("[waiting] found items, waiting 3s for more...")
        os.sleep(3)

        while (squirtle.suck(inputChestSide)) do
        end

        print("[task] navigating tunnel to output chest")
        navigateTunnel()

        local outputChestSide, outputChestSideError = findSideOfNearbyChest()

        if (not outputChestSide) then
            error(outputChestSideError)
        end

        squirtle.turnTo(outputChestSide)
        print("[status] unloading...")

        for slot = 1, 16 do
            turtle.select(slot)
            squirtle.drop(outputChestSide)
        end

        print("[status] unloaded as much as i could")
        print("[task] navigating tunnel to input chest")
        navigateTunnel()
    end
end

main()
