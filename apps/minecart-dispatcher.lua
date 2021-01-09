package.path = package.path .. ";/libs/?.lua"

local Inventory = require "inventory"
local Peripheral = require "peripheral"
local Sides = require "sides"
local Turtle = require "turtle"
local Utils = require "utils"

local function main(args)
    print("[minecart-dispatcher @ 1.0.0]")

    if args[1] == "autorun" then
        Utils.writeAutorunFile({"minecart-dispatcher"})
    end

    local input, inputSide = Peripheral.wrapOne({"minecraft:chest"})

    if not input then
        error("no nearby chest found")
    end

    inputSide = Turtle.faceSide(inputSide)

    local barrel, barrelSide = Peripheral.wrapOne({"minecraft:barrel"}, Sides.horizontal())

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
            local dumpedAll = Inventory.dumpTo("bottom")

            if not dumpedAll then
                print("could not dump more items, dispatching minecart...")
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
