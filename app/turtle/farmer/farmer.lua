package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Squirtle = require "squirtle"
local doHomework = require "farmer.do-homework"
local doFieldWork = require "farmer.do-field-work"
local isCrops = require "farmer.is-crops"

---@param block Block
local function getBlockTurnSide(block)
    if block.name == "minecraft:spruce_fence" then
        return "left"
    elseif block.name == "minecraft:oak_fence" then
        return "right"
    else
        if math.random() < .5 then
            return "left"
        else
            return "right"
        end
    end
end

local function moveNext()
    while not Squirtle.tryMove() do
        local block = Squirtle.inspect()

        if not block then
            print("could not move even though front seems to be free")

            while not block do
                os.sleep(1)
                block = Squirtle.inspect()
            end
        end

        Squirtle.turn(getBlockTurnSide(block))
    end
end

-- the only way for the turtle to find home is to find a chest at bottom,
-- at which point the turtle will move back and then down. it'll then
-- expect there to be a barrel - otherwise errors out.
-- this strict requirement makes it so that we never have to move down
-- a block to check if we reached home, which is gud.
---@param args table
local function main(args)
    print("[farmer v1.4.0] booting...")
    Squirtle.setBreakable(isCrops)

    while true do
        local block = Squirtle.inspect("bottom")

        if block and block.name == "minecraft:chest" then
            Squirtle.back()
            Squirtle.down()
        else
            if block and block.name == "minecraft:barrel" then
                doHomework()
            elseif block and block.name == "minecraft:spruce_fence" then
                Squirtle.turn(getBlockTurnSide(block))
            elseif block and block.name == "minecraft:oak_fence" then
                Squirtle.turn(getBlockTurnSide(block))
            else
                doFieldWork(block)
            end

            moveNext()
        end
    end
end

main(arg)
