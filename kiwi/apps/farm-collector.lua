package.path = package.path .. ";/?.lua"

local Side = require "kiwi.core.side"
local inspect = require "kiwi.turtle.inspect"
local move = require "kiwi.turtle.move"
local turn = require "kiwi.turtle.turn"
local Peripheral = require "kiwi.core.peripheral"
local Inventory = require "kiwi.turtle.inventory"
local Fuel = require "kiwi.core.fuel"
local refuel = require "kiwi.turtle.refuel"

local function doHomeStuff()
    print("at home! doing home stuff...")

    print("dumping items...")
    local stacks = Inventory.list()

    for slot, stack in pairs(stacks) do
        -- if not Fuel.isFuel(stack.name) then
        Inventory.selectSlot(slot)
        turtle.dropDown()
        -- end
    end

    -- -- make sure to condense fuel down as were gonna count in number of stacks rather than level
    -- -- want 4 stacks, 1 for each farm
    -- Inventory.condense()

    local chest, chestSide = Peripheral.wrapOne({"minecraft:chest"})
    local barrel, barrelSide = Peripheral.wrap(Side.bottom), Side.bottom
    local fuelInBarrel = Fuel.sumFuel(barrel.list())
    -- local targetFuelLevel = 7000

    if fuelInBarrel < 7000 then
        local fuelStacks = Fuel.pickStacks(chest.list(), 7000 - fuelInBarrel, 80)

        for slot, _ in pairs(fuelStacks) do
            chest.pushItems(Side.getName(barrelSide), slot)
        end
    end

    for slot, stack in pairs(barrel.list()) do
        if not Fuel.isFuel(stack.name) then
            barrel.pushItems(Side.getName(chestSide), slot)
        end
    end

    while turtle.suckDown() do
    end

    -- if Fuel.sumFuel(Inventory.list()) < 1000 then
    --     print("not enough")
    -- end

    print("(sleeping 3s to simulate home stuff")
    os.sleep(3)
    print("home stuff ready!")
    refuel(80)
end

local function main(args)
    while true do
        local bottom = inspect(Side.bottom)

        if bottom and bottom.name == "minecraft:barrel" then
            doHomeStuff()
        end

        if not move() then
            local block = inspect()

            if not block then
                error("could not move even though there is nothing in front of me")
            end

            if block.name == "minecraft:chest" then
                local barrel = Peripheral.wrap(Side.left)

                if barrel then
                    local fuelInBarrel = Fuel.sumFuel(barrel.list())

                    if fuelInBarrel < 7000 then
                        turn(Side.left)
                        local stacks = Fuel.pickStacks(Inventory.list(), 7000 - fuelInBarrel, 80)

                        for slot, _ in pairs(stacks) do
                            Inventory.selectSlot(slot)
                            turtle.drop()
                        end
                        turn(Side.right)
                    end
                end

                while turtle.suck() do
                end

                turn(Side.right)
            end
        end
    end
end

return main(arg)
