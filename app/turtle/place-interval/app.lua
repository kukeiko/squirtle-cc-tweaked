package.path = package.path .. ";/lib/?.lua"

local Utils = require "squirtle.libs.utils"
local Turtle = require "squirtle.libs.turtle"
local Side = require "squirtle.libs.side"
local Cardinal = require "squirtle.libs.cardinal"
local Vector = require "squirtle.libs.vector"
local Inventory = require "squirtle.libs.turtle.inventory"
local Refueler = require "squirtle.libs.turtle.refueler"

local sidesByDirectionArg = {forward = Side.front, up = Side.top, down = Side.bottom}

local function parseAndValidateArguments(args)
    local intervalArg = args[1]
    local interval = tonumber(intervalArg)

    if interval == nil or interval <= 0 then
        error("invalid interval provided as an argument: " .. tostring(intervalArg))
    end

    local directionArg = args[2]
    local side = Side.front

    if directionArg ~= nil then
        side = sidesByDirectionArg[directionArg]

        if side == nil then
            error("invalid direction provided as an argument: " .. tostring(directionArg))
        end
    end

    return interval, side
end

local function main(args)
    print("[place-interval @ 1.0.0]")
    local interval, side = parseAndValidateArguments(args)

    print(interval)
    print(side)

    local orientation, position = Turtle.orientate()
    print(Cardinal.getName(orientation), position)

    if side == Side.front then
        local firstBlockPosition = position:plus(Cardinal.toVector(Cardinal.down))
        print("first block at:", firstBlockPosition)
    elseif side == Side.top then
        local firstBlockPosition = position:plus(Cardinal.toVector(orientation))
        print("first block at:", firstBlockPosition)
    elseif side == Side.bottom then
        local firstBlockPosition = position:plus(Cardinal.toVector(orientation))
        print("first block at:", firstBlockPosition)
    end

    ---@type ItemStack[]
    local blocks = {}

    for slot = 1, Inventory.size() do
        local stack = Inventory.getStack(slot)

        if stack == nil then
            break
        end

        table.insert(blocks, stack)
    end

    local numBlocks = 0

    for i = 1, #blocks do
        numBlocks = numBlocks + blocks[i].count
    end

    local requiredFuel = numBlocks * 3
    local missingFuel = Turtle.getMissingFuel(requiredFuel)

    if missingFuel > 0 then
        print(missingFuel .. " additional fuel required...")
        missingFuel = Refueler.refuelFromInventory(missingFuel)

        if missingFuel > 0 then
            Refueler.refuelWithHelpFromPlayer(missingFuel)
        end
    end
    -- local position = Turtle.getPosition()
    -- print("position:", position)
    -- local nextChunk = position:asChunkIndex():plus(Vector.new(1, 0, 0))
    -- local target = nextChunk:multiply(16)
    -- target.y = position.y
    -- print("target:", target)
    -- Turtle.moveToPointAggressive(target)

    -- setup()
    -- todo: this app requires GPS because on unload the interval count gets lost
    -- with GPS however, we could store all points where to place a block
    -- on disk on app setup.
end

local function setup()
    print("What's the interval chef?")

    local interval = Utils.readPositiveInteger()
    print(interval)

    print(
        "Please make sure I have the exact number of blocks I should place in my inventory (and nothing else), then hit enter.")
    Utils.waitForUserToHitEnter()

end

local function windowTest()
    local parent = term.current()
    -- local width, height = parent.getSize()
    -- local win = window.create(parent, 5, 2, width, height - 1, false)
    -- win.write("Hello!")
    -- win.setVisible(true)
    -- win.setVisible(false)
end

main(arg)
