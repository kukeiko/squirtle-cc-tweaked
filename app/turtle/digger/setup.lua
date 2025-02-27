local Vector = require "lib.models.vector"
local World = require "lib.models.world"
local Cardinal = require "lib.models.cardinal"
local Squirtle = require "lib.squirtle.squirtle-api"
local Inventory = require "lib.apis.inventory.inventory-api"

local function getDirection()
    while true do
        local _, key = os.pullEvent("key")

        if key == keys.a then
            Squirtle.turn("left")
        elseif key == keys.d then
            Squirtle.turn("right")
        elseif key == keys.enter then
            break
        end
    end

    return Squirtle.getFacing()
end

local function readNumber(msg, min)
    print(msg)
    local value

    while not value do
        value = tonumber(read())

        if min and value < min then
            value = nil
        end
    end

    return value
end

local function readMineableBlocks()
    ---@type table<string, unknown>
    local mineable = {}
    local chest = Inventory.findChest()

    -- for _, stack in pairs(Inventory.getOutputStacks(chest)) do
    --     mineable[stack.name] = true -- [todo] value doesn't matter (typed it to unknown) - can we find a use?
    -- end

    return mineable
end

return function()
    print("setup!")
    local position = Squirtle.getPosition()
    -- [todo] make sure barrel and io-chest are placed

    print("use a/d keys to let me look towards 1st digging direction, then hit enter")
    local firstDirection = getDirection()
    local firstLength = readNumber("how far should I dig towards " .. Cardinal.getName(firstDirection), 1)
    local firstOffset =
        readNumber("how many steps should i take towards " .. Cardinal.getName(firstDirection) .. " before I start digging?")

    print("now towards the 2nd digging direction")
    local secondDirection = getDirection()

    while (secondDirection == firstDirection) or secondDirection == Cardinal.rotateAround(firstDirection) do
        if secondDirection == firstDirection then
            print("can not be the same direction! again please.")
        else
            print("can not be inverse direction of the first. again please")
        end

        secondDirection = getDirection()
    end

    local secondLength = readNumber("how far should I dig towards that direction?", 1)
    local secondOffset = readNumber("how many steps should i take towards " .. Cardinal.getName(secondDirection) ..
                                        " before I start digging?")

    local x, y, z, width, depth, height

    if firstDirection == Cardinal.north then
        depth = firstLength
        z = position.z - firstOffset - (depth - 1)
    elseif firstDirection == Cardinal.south then
        z = position.z + firstOffset
        depth = firstLength
    elseif firstDirection == Cardinal.east then
        width = firstLength
        x = position.x + firstOffset
    elseif firstDirection == Cardinal.west then
        width = firstLength
        x = position.x - firstOffset - (width - 1)
    end

    if secondDirection == Cardinal.north then
        depth = secondLength
        z = position.z - secondOffset - (depth - 1)
    elseif secondDirection == Cardinal.south then
        z = position.z + secondOffset
        depth = secondLength
    elseif secondDirection == Cardinal.east then
        width = secondLength
        x = position.x + secondOffset
    elseif secondDirection == Cardinal.west then
        width = secondLength
        x = position.x - secondOffset - (width - 1)
    end

    -- [todo] allow user to specify up/down + height (with "0" or empty being "until limit")
    -- [todo] update for 1.18
    y = -59
    height = position.y - y

    ---@type World
    local world = World.create(x, y, z, width, height, depth)
    local start = World.getClosestCorner(world, position)

    print("reading output stacks to see what i'm allowed to mine...")
    local mineable = readMineableBlocks()

    ---@type DiggerAppState
    local state = {
        world = world,
        home = position,
        start = start,
        checkpoint = Vector.create(start.x, start.y, start.z),
        mineable = mineable
    }

    return state
end
