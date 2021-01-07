package.path = package.path .. ";/libs/?.lua"

local Inventory = require "inventory"
local Sides = require "sides"
local Squirtle = require "squirtle"
local Turtle = require "turtle"

local function writeStartupFile()
    local file = fs.open("startup/minecart-dispatcher.autorun.lua", "w")
    file.write("shell.run(\"minecart-dispatcher\")")
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

    inputSide = Turtle.faceSide(inputSide)

    local barrel, barrelSide = Squirtle.wrapPeripheral({"minecraft:barrel"}, Sides.horizontal())

    if not barrel then
        error("no nearby barrel found")
    end

    while true do
        local suckSide, undoFaceInput = Turtle.faceSide(inputSide)

        while Turtle.suck(suckSide) do
        end

        undoFaceInput()

        if not Inventory.isEmpty() then
            print("found items! waiting for minecart...")
            Inventory.selectFirstOccupiedSlot()
            local dropSide, undoFaceBarrel = Turtle.faceSide(barrelSide)
            Turtle.drop(dropSide, 1)

            while not Turtle.suck("bottom") do
            end

            undoFaceBarrel()

            print("minecart is here! filling it up...")
            local minecartFull = false

            for slot = 1, Inventory.size() do
                if turtle.getItemCount(slot) > 0 then
                    turtle.select(slot)

                    if not Turtle.drop("bottom") then
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
