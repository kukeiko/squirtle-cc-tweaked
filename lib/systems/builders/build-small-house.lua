local TurtleApi = require "lib.apis.turtle.turtle-api"
local ItemApi = require "lib.apis.item-api"

local up = TurtleApi.up
local down = TurtleApi.down
local left = TurtleApi.left
local right = TurtleApi.right
local forward = TurtleApi.forward
local back = TurtleApi.back
local ahead = TurtleApi.ahead
local below = TurtleApi.below
local above = TurtleApi.above
local strafe = TurtleApi.strafe
local around = TurtleApi.around
local dig = TurtleApi.dig

---@param direction? string
local function clickTrapdoor(direction)
    if not TurtleApi.isSimulating() then
        while not TurtleApi.selectItem(ItemApi.diskDrive) do
            TurtleApi.requireItem(ItemApi.diskDrive, 1)
        end

        TurtleApi.place(direction)
    end
end

---@param direction? string
---@param item? string
local function digHelperBlock(direction, item)
    dig(direction)

    -- [todo] ❌ doesn't actually work the way I need it - would need similar logic like we have it for water & lava.
    -- so for now we just ignore recording taken blocks and the turtle will just end up with a few more items in its inventory
    -- after it has finished building the house.
    -- if TurtleApi.isSimulating() then
    --     TurtleApi.recordTakenBlock(item or ItemApi.dirt)
    -- end
end

local function buildFoundation()
    right()
    forward(1)
    right()
    back()
    ahead(ItemApi.dirt) -- helper block to orientate placed log

    -- left border going back
    for i = 1, 5 do
        back()
        ahead(ItemApi.strippedSpruceLog)

        if i >= 2 and i <= 4 then
            left()
            ahead(ItemApi.sprucePlanks)
            right()
        end
    end

    -- back border & right border
    for _ = 1, 2 do
        for _ = 1, 2 do
            right()
            forward()
            ahead(ItemApi.dirt) -- helper block to orientate placed log
            back()
            ahead(ItemApi.strippedSpruceLog)
        end

        left()

        for i = 1, 4 do
            back()
            ahead(ItemApi.strippedSpruceLog)

            if i >= 2 and i <= 3 then
                left()
                ahead(ItemApi.sprucePlanks)
                right()
            end
        end
    end

    -- bottom right corner
    for _ = 1, 2 do
        right()
        forward()
        ahead(ItemApi.dirt) -- helper block to orientate placed log
        back()
        ahead(ItemApi.strippedSpruceLog)
    end

    -- front border
    left()
    back()
    ahead(ItemApi.strippedSpruceLog)
    back()
    ahead(ItemApi.strippedSpruceLog)
    left()
    -- fill in remaining floor
    forward()
    ahead(ItemApi.sprucePlanks)
    back()
    ahead(ItemApi.sprucePlanks)
    left()
    ahead(ItemApi.strippedSpruceLog)
    up()
    below(ItemApi.strippedSpruceLog) -- entrance block at door
    forward(4)
    down()
    around()
    ahead(ItemApi.strippedSpruceLog)
end

local function buildWalls()
    up(2)
    forward(2)
    -- layer #1
    below(ItemApi.strippedSpruceLog)
    forward()
    below(ItemApi.sprucePlanks)
    forward(2) -- skip the doorway
    below(ItemApi.sprucePlanks)

    for _ = 1, 3 do
        forward()
        below(ItemApi.strippedSpruceLog)
        left()

        for _ = 1, 3 do
            forward()
            below(ItemApi.sprucePlanks)
        end
    end

    -- layer #2
    forward()
    up()
    left()
    below(ItemApi.strippedSpruceLog)
    forward()
    below(ItemApi.sprucePlanks)
    forward(2) -- skip the doorway
    below(ItemApi.sprucePlanks)

    for _ = 1, 3 do
        forward()
        below(ItemApi.strippedSpruceLog)
        left()
        forward()
        below(ItemApi.sprucePlanks)
        forward()
        below(ItemApi.glassPane)
        forward()
        below(ItemApi.sprucePlanks)
    end

    -- layer #3
    forward()
    up()

    for i = 1, 4 do
        left()
        below(ItemApi.strippedSpruceLog)

        for _ = 1, 3 do
            forward()
            below(ItemApi.sprucePlanks)
        end

        if i ~= 4 then
            forward()
        end
    end
end

local function buildFurniture()
    right()
    back()
    down(2)
    below(ItemApi.chest)
    right()
    forward()
    below(ItemApi.redCarpet)
    forward()
    below(ItemApi.lectern)
    right()
    forward()
    below(ItemApi.redCarpet)
    forward()
    below(ItemApi.beehive)
    up()
    below(ItemApi.flowerPot)
    below(ItemApi.poppy) -- [todo] ❌ not the best method to use as it will try to mine a block if it failed to place
    left()
    back(2)
    down()
    below(ItemApi.lightBlueBed)
    left()
    forward()
    down()
    left()
    ahead(ItemApi.spruceDoor)
    up()
    below(ItemApi.redCarpet)
    back()
    below(ItemApi.redCarpet)
    up()
    above(ItemApi.strippedSpruceLog)
    down()
    above(ItemApi.lantern)
end

local function buildCeiling()
    forward()
    up(2)
    forward(2)
    right()
    forward(2)
    left()

    ahead(ItemApi.dirt) -- helper block to orientate placed log

    -- left border going back
    for i = 1, 5 do
        back()
        ahead(ItemApi.strippedSpruceLog)

        if i >= 2 and i <= 4 then
            left()
            ahead(ItemApi.sprucePlanks)
            right()
        end
    end

    -- back border & right border
    for j = 1, 2 do
        for _ = 1, 2 do
            right()
            forward()
            ahead(ItemApi.dirt) -- helper block to orientate placed log
            back()
            ahead(ItemApi.strippedSpruceLog)
        end

        left()

        for i = 1, 4 do
            back()
            ahead(ItemApi.strippedSpruceLog)

            if i >= 2 and i <= 3 then
                left()
                ahead(ItemApi.sprucePlanks)
                right()
            end
        end
    end

    -- bottom right corner
    for _ = 1, 2 do
        right()
        forward()
        ahead(ItemApi.dirt) -- helper block to orientate placed log
        back()
        ahead(ItemApi.strippedSpruceLog)
    end

    -- front border
    left()

    for i = 1, 3 do
        back()
        ahead(ItemApi.strippedSpruceLog)

        if i == 2 then
            left()
            ahead(ItemApi.sprucePlanks)
            right()
        end
    end

    up()
    back()
    digHelperBlock("down", ItemApi.strippedSpruceLog)
    down()
    ahead(ItemApi.strippedSpruceLog)

    for _ = 1, 2 do
        back()
        ahead(ItemApi.strippedSpruceLog)
    end
end

local function buildRoofFoundation()
    up(2)
    forward(3)
    right()

    -- place front slabs
    forward()
    left()

    for i = 1, 3 do
        below(ItemApi.darkOakSlab)

        if i ~= 3 then
            forward()
        end
    end

    -- move back while placing right foundation line
    left()

    for _ = 1, 5 do
        forward()
        below(ItemApi.sprucePlanks)
    end

    forward()
    left()

    -- place back slabs
    for i = 1, 3 do
        below(ItemApi.darkOakSlab)

        if i ~= 3 then
            forward()
        end
    end

    -- move forward while placing left foundation line
    left()

    for _ = 1, 5 do
        forward()
        below(ItemApi.sprucePlanks)
    end

    -- move back while placing center foundation line
    left()
    forward()
    left()

    for _ = 1, 5 do
        below(ItemApi.sprucePlanks)
        forward()
    end

    -- place top center line
    forward()
    up()
    around()
    below(ItemApi.spruceStairs)

    for _ = 1, 7 do
        forward()
        below(ItemApi.sprucePlanks)
    end

    forward()
    around()
    below(ItemApi.spruceStairs)
end

local function buildRoofTiles()
    -- top line back
    for i = 1, 7 do
        ahead(ItemApi.darkOakStairs)

        if i ~= 7 then
            strafe("right")
        end
    end

    -- center line forward
    back()
    down()

    for i = 1, 7 do
        ahead(ItemApi.darkOakStairs)

        if i ~= 7 then
            strafe("left")
        end
    end

    -- bottom line back
    back()
    down()
    ahead(ItemApi.darkOakStairs)
    right()
    forward(2)
    left()

    for i = 1, 3 do
        ahead(ItemApi.darkOakStairs)

        if i ~= 3 then
            strafe("right")
        end
    end

    right()
    forward(2)
    left()
    ahead(ItemApi.darkOakStairs)

    -- move to other side while placing trapdoors
    right()
    forward()
    left()
    forward(3)
    left()

    for i = 1, 3 do
        ahead(ItemApi.trapdoor)
        clickTrapdoor()

        if i ~= 3 then
            right()
            forward()

            if i == 2 then
                -- remove helper block used for orientating log
                if not TurtleApi.isSimulating() then
                    TurtleApi.dig()
                end
            end

            left()
        end
    end
end

local function buildRoof()
    forward()
    left()
    back(2)
    down()

    -- build right side tiles
    buildRoofTiles()

    up(2)
    forward()
    left()
    back()

    -- build left side tiles
    buildRoofTiles()
end

local function buildOuterDecoration()
    -- build front decoration
    down(4)
    ahead(ItemApi.grassBlock)
    up()
    below(ItemApi.trapdoor)
    clickTrapdoor("bottom")
    ahead(ItemApi.oakLeaves)
    left()
    forward()
    down()
    below(ItemApi.stone)
    right()
    ahead(ItemApi.stoneStairs)
    strafe("left")
    ahead(ItemApi.grassBlock)
    up()
    below(ItemApi.trapdoor)
    clickTrapdoor("bottom")
    forward()
    up()
    below(ItemApi.oakLeaves)
    left()
    forward()

    for side = 1, 3 do
        if side == 1 or side == 3 then
            above(ItemApi.lantern)
        end

        -- place corner fences
        below(ItemApi.darkOakFence)
        forward()
        down()
        below(ItemApi.darkOakFence)
        up()
        below(ItemApi.darkOakFence)
        right()
        forward()
        below(ItemApi.darkOakFence)

        if side == 2 then
            above(ItemApi.lantern)
        end

        -- front side left corner is the only one without a helper block
        if side == 1 then
            forward()
            right()
            back()
            down()
        else
            right()
            back()
            down()
            digHelperBlock("bottom")
            strafe("left")
        end

        for _ = 1, 3 do
            below(ItemApi.spruceTrapdoor)
            clickTrapdoor("bottom")
            strafe("left")
        end

        digHelperBlock("down")

        -- place grass
        forward()
        left()

        for _ = 1, 3 do
            back()
            below(ItemApi.grassBlock)
        end

        -- place bush
        up()

        for _ = 1, 3 do
            below(ItemApi.oakLeaves)
            forward()
        end
    end

    -- place front right corner fence
    below(ItemApi.darkOakFence)
    forward()
    down()
    below(ItemApi.darkOakFence)
    up()
    below(ItemApi.darkOakFence)
    right()
    forward()
    below(ItemApi.darkOakFence)
    above(ItemApi.lantern)

    -- head back to start and remove last 2 helper blocks
    left()
    forward()
    down()
    digHelperBlock("bottom")
    right()
    forward(4)
    digHelperBlock("bottom")
    forward()
    down()
    right()
end

return function()
    buildFoundation()
    buildWalls()
    buildFurniture()
    buildCeiling()
    buildRoofFoundation()
    buildRoof()
    buildOuterDecoration()
end
