if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

package.path = package.path .. ";/app/turtle/?.lua"
local TurtleApi = require "lib.apis.turtle.turtle-api"
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
    while not TurtleApi.tryWalk() do
        local block = TurtleApi.probe()

        if not block then
            print("could not move even though front seems to be free")

            while not block do
                os.sleep(1)
                block = TurtleApi.probe()
            end
        end

        TurtleApi.turn(getBlockTurnSide(block))
    end
end

-- the only way for the turtle to find home is to find a chest at bottom,
-- at which point the turtle will move back and then down. it'll then
-- expect there to be a barrel - otherwise errors out.
-- this strict requirement makes it so that we never have to move down
-- a block to check if we reached home, which is gud.
---@param args table
local function main(args)
    print(string.format("[farmer %s] booting...", version()))
    TurtleApi.setBreakable(isCrops)

    while true do
        local block = TurtleApi.probe("bottom")

        if block and block.name == "minecraft:chest" then
            TurtleApi.walk("back")
            TurtleApi.walk("down")
        else
            if block and block.name == "minecraft:barrel" then
                doHomework()
            elseif block and block.name == "minecraft:spruce_fence" then
                TurtleApi.turn(getBlockTurnSide(block))
            elseif block and block.name == "minecraft:oak_fence" then
                TurtleApi.turn(getBlockTurnSide(block))
            else
                doFieldWork(block)
            end

            moveNext()
        end
    end
end

main(arg)
