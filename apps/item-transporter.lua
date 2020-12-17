package.path = package.path .. ";/libs/?.lua"

local Squirtle = require "squirtle"

function navigateTunnel(checkEarlyExit)
    local forbidden

    while true do
        local strategy

        if turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif forbidden ~= "up" and turtle.up() then
            strategy = "up"
            forbidden = "down"
        elseif forbidden ~= "down" and turtle.down() then
            strategy = "down"
            forbidden = "up"
        elseif turtle.turnLeft() and turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif turtle.turnLeft() and forbidden ~= "back" and turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif turtle.turnLeft() and turtle.forward() then
            strategy = "forward"
            forbidden = "back"
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

        if checkEarlyExit ~= nil and checkEarlyExit() then
            return checkEarlyExit()
        end
    end
end

function findSideOfNearbyChest()
    local _, side = Squirtle.wrapChest()

    return side
end

function main()
    print("[item-transporter @ 1.5.0]")
    local minFuelPercent = 10

    while (true) do
        Squirtle.preTaskRefuelRoutine(minFuelPercent)

        print("[waiting] checking input chest...")
        local inputChestSide = findSideOfNearbyChest()

        if (not inputChestSide) then
            error("No nearby chest available")
        end

        local suckSide = inputChestSide

        if Squirtle.turnTo(inputChestSide) then
            suckSide = "front"
        end

        while not Squirtle.suck(suckSide) do
            os.sleep(3)
        end

        print("[waiting] found items, waiting 3s for more...")
        os.sleep(3)

        while (Squirtle.suck(suckSide)) do
        end

        Squirtle.refuelUsingLocalLava()
        Squirtle.printFuelLevelToMonitor(minFuelPercent)

        print("[task] navigating tunnel to output chest")

        local outputChestSide, outputChestSideError = navigateTunnel(findSideOfNearbyChest)

        if (not outputChestSide) then
            error(outputChestSideError)
        end

        local dropSide = outputChestSide

        if Squirtle.turnTo(outputChestSide) then
            dropSide = "front"
        end

        print("[status] unloading...")

        for slot = 1, 16 do
            turtle.select(slot)
            Squirtle.drop(dropSide)
        end

        print("[status] unloaded as much as i could")
        print("[task] navigating tunnel to input chest")
        navigateTunnel(findSideOfNearbyChest)
    end
end

main()
