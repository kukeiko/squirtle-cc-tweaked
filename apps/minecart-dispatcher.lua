package.path = package.path .. ";/libs/?.lua"

local Sides = require "sides"
local Squirtle = require "squirtle"

local function writeStartupFile()
    local file = fs.open("startup/minecart-dispatcher.autorun.lua", "w")
    file.write("shell.run(\"minecart-dispatcher\"")
    file.close()
end

local function main(args)
    print("[minecart-dispatcher @ 1.0.0]")

    if args[1] == "autorun" then
        writeStartupFile()
    end

    local input, inputSide = Squirtle.wrapPeripheral({"minecraft:chest"})

    if not input then
        error("no nearby chest found")
    end

    inputSide = Squirtle.facePeripheral(inputSide)

    local barrel, barrelSide = Squirtle.wrapPeripheral({"minecraft:barrel"}, Sides.horizontal())

    if not barrel then
        error("no nearby barrel found")
    end

    while true do
        local suckSide = Squirtle.facePeripheral(inputSide)

        while Squirtle.suck(suckSide) do
        end

        Squirtle.tryUndoTurn(inputSide)

        if not Squirtle.isEmpty() then
            print("found items! waiting for minecart...")
            Squirtle.selectFirstNonEmptySlot()
            local dropSide = Squirtle.facePeripheral(barrelSide)
            Squirtle.drop(dropSide, 1)

            while not Squirtle.suck("bottom") do
            end

            Squirtle.tryUndoTurn(barrelSide)

            print("minecart is here! filling it up...")
            local minecartFull = false

            for slot = 1, Squirtle.numSlots() do
                if turtle.getItemCount(slot) > 0 then
                    turtle.select(slot)

                    if not Squirtle.drop("bottom") then
                        minecartFull = true
                    end
                end
            end

            if minecartFull then
                print("minecart is full, dispatching...")
                redstone.setOutput("bottom", true)
                os.sleep(1)
                redstone.setOutput("bottom", false)
                print("minecart dispatched!")
            else
                print("minecart not yet full")
            end
        else
            print("no items found, waiting for 7s")
            os.sleep(7)
        end
    end
end

main(arg)
