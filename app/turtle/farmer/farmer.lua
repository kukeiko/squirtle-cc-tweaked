package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local inspect = require "squirtle.inspect"
local move = require "squirtle.move"
local turn = require "squirtle.turn"
local doHomework = require "farmer.do-homework"
local doFieldWork = require "farmer.do-field-work"

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
    while not move() do
        local block = inspect()

        if not block then
            print("could not move even though front seems to be free")

            while not block do
                os.sleep(1)
                block = inspect()
            end
        end

        turn(getBlockTurnSide(block))
    end
end

-- the only way for the turtle to find home is to find a chest at bottom,
-- at which point the turtle will move back and then down. it'll then
-- expect there to be a barrel - otherwise errors out.
-- this strict requirement makes it so that we never have to move down
-- a block to check if we reached home, which is gud.
---@param args table
local function main(args)
    print("[farmer v1.3.1] booting...")

    while true do
        local block = inspect("bottom")

        if block and block.name == "minecraft:chest" then
            move("back")
            move("bottom")
        else
            if block and block.name == "minecraft:barrel" then
                doHomework()
            elseif block and block.name == "minecraft:spruce_fence" then
                turn("left")
            elseif block and block.name == "minecraft:oak_fence" then
                turn("right")
            else
                doFieldWork(block)
            end

            moveNext()
        end
    end
end

main(arg)
