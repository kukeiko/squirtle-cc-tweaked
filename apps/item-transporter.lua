package.path = package.path .. ";/libs/?.lua"

local squirtle = require "squirtle"

function main()
    print("[item-transporter @ 1.0.0]")
    local minFuelPercent = 32

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
        while not turtle.suckDown() do os.sleep(3) end
        print("[waiting] found items, waiting 3s for more...")
        os.sleep(3)
        while (turtle.suckDown()) do end

        print("[debug] trying to find direction to output chest")
        while not turtle.forward() do turtle.turnLeft() end

        print("[task] unloading to output chest")
        while turtle.forward() do end

        print("[status] unloading...")
        for slot = 1, 16 do
            turtle.select(slot)
            turtle.dropDown()
        end

        print("[status] unloaded as much as i could")
        print("[debug] trying to find direction to input chest")
        while not turtle.forward() do turtle.turnLeft() end

        print("[status] moving to input chest")
        while turtle.forward() do end
    end
end

main()
