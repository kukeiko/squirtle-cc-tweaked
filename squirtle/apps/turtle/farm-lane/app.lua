package.path = package.path .. ";/?.lua"

local Turtle = require "squirtle.libs.turtle"
local Side = require "squirtle.libs.side"
local Utils = require "squirtle.libs.utils"

local function farm()
end

local function atHome()
    local i = 1, 4 do
        local frontBock = Turtle.getBlockAt(Side.front)
    end
end

local function main(args)
    print("[farm-lane @ 1.0.0]")

    while true do
        local bottomBlock = Turtle.getBlockAt(Side.bottom)

        if bottomBlock and bottomBlock.name == "minecraft:barrel" then
            atHome()
        end
    end

    -- local bottomOccupied, bottomBlock = Turtle.inspectDown()

    -- if bottomOccupied then
    --     if bottomBlock.name == "minecraft:snow" then
    --         -- [todo] can't deal with this as we don't have a pickaxe.
    --         -- could wait for user to manually clear snow,
    --         -- then prompt them to press a key to retry
    --         error("snow detected - no pickaxe to remove it")
    --     elseif bottomBlock.name == "minecraft:barrel" then
    --         print("i am at home! early exit as not yet implemented")
    --         return
    --     end
    -- else
    --     Turtle.down()
    --     -- check bottom block again
    --     local groundOccupied, groundBlock = Turtle.inspectDown()

    --     if groundOccupied then
    --         if groundBlock.name == "minecraft:dirt" then
    --             print("i was just about to plant something into tilled farmland")

    --         elseif groundBlock.name == "minecraft:barrel" then
    --             print("i was about to start harvesting")
    --             -- check if front block is a farm block. if not, throw error?
    --         end
    --     end
    -- end

    -- Utils.prettyPrint(bottomBlock)
end

return main(arg)
