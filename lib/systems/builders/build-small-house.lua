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

---
---@alias BuildSmallHouseTheme "spruce" | "oak"
---

---@param direction? string
local function clickTrapdoor(direction)
    TurtleApi.use(direction, ItemApi.diskDrive, true)
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

---@param theme BuildSmallHouseTheme
local function log(theme)
    if theme == "spruce" then
        return ItemApi.strippedSpruceLog
    else
        return ItemApi.strippedOakLog
    end
end

---@param theme BuildSmallHouseTheme
local function planks(theme)
    if theme == "spruce" then
        return ItemApi.sprucePlanks
    else
        return ItemApi.oakPlanks
    end
end

---@param theme BuildSmallHouseTheme
local function fence(theme)
    if theme == "spruce" then
        return ItemApi.darkOakFence
    else
        return ItemApi.spruceFence
    end
end

---@param theme BuildSmallHouseTheme
local function slab(theme)
    if theme == "spruce" then
        return ItemApi.darkOakSlab
    else
        return ItemApi.spruceSlab
    end
end

---@param theme BuildSmallHouseTheme
local function stairs(theme)
    if theme == "spruce" then
        return ItemApi.spruceStairs
    else
        return ItemApi.oakStairs
    end
end

---@param theme BuildSmallHouseTheme
local function roofStairs(theme)
    if theme == "spruce" then
        return ItemApi.darkOakStairs
    else
        return ItemApi.spruceStairs
    end
end

---@param theme BuildSmallHouseTheme
local function buildFoundation(theme)
    right()
    forward(1)
    right()
    back()
    ahead(ItemApi.dirt) -- helper block to orientate placed log

    -- left border going back
    for i = 1, 5 do
        back()
        ahead(log(theme))

        if i >= 2 and i <= 4 then
            left()
            ahead(planks(theme))
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
            ahead(log(theme))
        end

        left()

        for i = 1, 4 do
            back()
            ahead(log(theme))

            if i >= 2 and i <= 3 then
                left()
                ahead(planks(theme))
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
        ahead(log(theme))
    end

    -- front border
    left()
    back()
    ahead(log(theme))
    back()
    ahead(log(theme))
    left()
    -- fill in remaining floor
    forward()
    ahead(planks(theme))
    back()
    ahead(planks(theme))
    left()
    ahead(log(theme))
    up()
    below(log(theme)) -- entrance block at door
    forward(4)
    down()
    around()
    ahead(log(theme))
end

---@param theme BuildSmallHouseTheme
local function buildWalls(theme)
    up(2)
    forward(2)
    -- layer #1
    below(log(theme))
    forward()
    below(planks(theme))
    forward(2) -- skip the doorway
    below(planks(theme))

    for _ = 1, 3 do
        forward()
        below(log(theme))
        left()

        for _ = 1, 3 do
            forward()
            below(planks(theme))
        end
    end

    -- layer #2
    forward()
    up()
    left()
    below(log(theme))
    forward()
    below(planks(theme))
    forward(2) -- skip the doorway
    below(planks(theme))

    for _ = 1, 3 do
        forward()
        below(log(theme))
        left()
        forward()
        below(planks(theme))
        forward()
        below(ItemApi.glassPane)
        forward()
        below(planks(theme))
    end

    -- layer #3
    forward()
    up()

    for i = 1, 4 do
        left()
        below(log(theme))

        for _ = 1, 3 do
            forward()
            below(planks(theme))
        end

        if i ~= 4 then
            forward()
        end
    end
end

---@param theme BuildSmallHouseTheme
local function buildFurniture(theme)
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
    above(log(theme))
    down()
    above(ItemApi.lantern)
end

---@param theme BuildSmallHouseTheme
local function buildCeiling(theme)
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
        ahead(log(theme))

        if i >= 2 and i <= 4 then
            left()
            ahead(planks(theme))
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
            ahead(log(theme))
        end

        left()

        for i = 1, 4 do
            back()
            ahead(log(theme))

            if i >= 2 and i <= 3 then
                left()
                ahead(planks(theme))
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
        ahead(log(theme))
    end

    -- front border
    left()

    for i = 1, 3 do
        back()
        ahead(log(theme))

        if i == 2 then
            left()
            ahead(planks(theme))
            right()
        end
    end

    up()
    back()
    digHelperBlock("down", log(theme))
    down()
    ahead(log(theme))

    for _ = 1, 2 do
        back()
        ahead(log(theme))
    end
end

---@param theme BuildSmallHouseTheme
local function buildRoofFoundation(theme)
    up(2)
    forward(3)
    right()

    -- place front slabs
    forward()
    left()

    for i = 1, 3 do
        below(slab(theme))

        if i ~= 3 then
            forward()
        end
    end

    -- move back while placing right foundation line
    left()

    for _ = 1, 5 do
        forward()
        below(planks(theme))
    end

    forward()
    left()

    -- place back slabs
    for i = 1, 3 do
        below(slab(theme))

        if i ~= 3 then
            forward()
        end
    end

    -- move forward while placing left foundation line
    left()

    for _ = 1, 5 do
        forward()
        below(planks(theme))
    end

    -- move back while placing center foundation line
    left()
    forward()
    left()

    for _ = 1, 5 do
        below(planks(theme))
        forward()
    end

    -- place top center line
    forward()
    up()
    around()
    below(stairs(theme))

    for _ = 1, 7 do
        forward()
        below(planks(theme))
    end

    forward()
    around()
    below(stairs(theme))
end

---@param theme BuildSmallHouseTheme
local function buildRoofTiles(theme)
    -- top line back
    for i = 1, 7 do
        ahead(roofStairs(theme))

        if i ~= 7 then
            strafe("right")
        end
    end

    -- center line forward
    back()
    down()

    for i = 1, 7 do
        ahead(roofStairs(theme))

        if i ~= 7 then
            strafe("left")
        end
    end

    -- bottom line back
    back()
    down()
    ahead(roofStairs(theme))
    right()
    forward(2)
    left()

    for i = 1, 3 do
        ahead(roofStairs(theme))

        if i ~= 3 then
            strafe("right")
        end
    end

    right()
    forward(2)
    left()
    ahead(roofStairs(theme))

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

---@param theme BuildSmallHouseTheme
local function buildRoof(theme)
    forward()
    left()
    back(2)
    down()

    -- build right side tiles
    buildRoofTiles(theme)

    up(2)
    forward()
    left()
    back()

    -- build left side tiles
    buildRoofTiles(theme)
end

---@param theme BuildSmallHouseTheme
local function buildOuterDecoration(theme)
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
        below(fence(theme))
        forward()
        down()
        below(fence(theme))
        up()
        below(fence(theme))
        right()
        forward()
        below(fence(theme))

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
    below(fence(theme))
    forward()
    down()
    below(fence(theme))
    up()
    below(fence(theme))
    right()
    forward()
    below(fence(theme))
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

---@param theme? BuildSmallHouseTheme
return function(theme)
    theme = theme or "spruce"
    buildFoundation(theme)
    buildWalls(theme)
    buildFurniture(theme)
    buildCeiling(theme)
    buildRoofFoundation(theme)
    buildRoof(theme)
    buildOuterDecoration(theme)
end
