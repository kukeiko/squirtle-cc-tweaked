local Utils = require "utils"
local Vectors = require "elements.vector"
local World = require "scout.world"
local Transform = require "scout.transform"
local Side = require "elements.side"
local Cardinal = require "elements.cardinal"
local orientate = require "squirtle.orientate"
local turn = require "squirtle.turn"

local function getDirection()
    while true do
        local _, key = os.pullEvent("key")

        if key == keys.a then
            turn(Side.left)
        elseif key == keys.d then
            turn(Side.right)
        elseif key == keys.enter then
            break
        end
    end

    local _, direction = orientate()

    return direction
end

local function readNumber(msg)
    print(msg)
    local width = 0

    while not width or width < 1 do
        width = tonumber(read())
    end

    return width
end

---@param home Vector
---@param world World
---@return Vector
local function determineStart(home, world)
    local corners = {
        Vectors.new(world.x, world.y, world.z),
        Vectors.new(world.x + world.width - 1, world.y, world.z),
        Vectors.new(world.x, world.y + world.height - 1, world.z),
        Vectors.new(world.x + world.width - 1, world.y + world.height - 1, world.z),
        --
        Vectors.new(world.x, world.y, world.z + world.depth - 1),
        Vectors.new(world.x + world.width - 1, world.y, world.z + world.depth - 1),
        Vectors.new(world.x, world.y + world.height - 1, world.z + world.depth - 1),
        Vectors.new(world.x + world.width - 1, world.y + world.height - 1, world.z + world.depth - 1)
    }

    ---@type Vector
    local best

    for i = 1, #corners do
        if best == nil or Vectors.length(best - home) > Vectors.length(corners[i] - home) then
            best = corners[i]
        end
    end

    return best
end

return function()
    print("setup!")
    local position = orientate()
    -- [todo] make sure barrel and io-chest are placed

    print("use a/d keys to let me look towards 1st digging direction, then hit enter")
    local firstDirection = getDirection()
    local firstLength = readNumber("how far should I dig towards that direction?")

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

    local secondLength = readNumber("how far should I dig towards that direction?")

    print(Cardinal.getName(firstDirection), Cardinal.getName(secondDirection), firstLength, secondLength)

    local x, y, z, width, depth, height

    if firstDirection == Cardinal.north then
        depth = firstLength
        z = position.z - (depth - 1)
    elseif firstDirection == Cardinal.south then
        z = position.z
        depth = firstLength
    elseif firstDirection == Cardinal.east then
        width = firstLength
        x = position.x
    elseif firstDirection == Cardinal.west then
        width = firstLength
        x = position.x - (width - 1)
    end

    if secondDirection == Cardinal.north then
        depth = secondLength
        z = position.z - (depth - 1)
    elseif secondDirection == Cardinal.south then
        z = position.z
        depth = secondLength
    elseif secondDirection == Cardinal.east then
        width = secondLength
        x = position.x
    elseif secondDirection == Cardinal.west then
        width = secondLength
        x = position.x - (width - 1)
    end

    y = 5
    height = position.y - y
    -- y = -60 -- todo: for 1.18

    local world = World.new(Transform.new(Vectors.new(x, y, z)), width, height, depth)
    Utils.prettyPrint(world)

    local start = determineStart(position, world)
    ---@type ExposeOresAppState
    local appState = {world = world, home = position, start = start, checkpoint = determineStart(position, world)}
    Utils.saveAppState(appState, "expose-ores")

    ---@type ExposeOresAppState
    local reloadedState = Utils.loadAppState("expose-ores", {})

    reloadedState.world = World.new(Transform.new(Vectors.new(reloadedState.world.x, reloadedState.world.y,
                                                              reloadedState.world.z)), reloadedState.world.width,
                                    reloadedState.world.height, reloadedState.world.depth)
    reloadedState.checkpoint = Vectors.cast(reloadedState.checkpoint)

    return reloadedState
end
