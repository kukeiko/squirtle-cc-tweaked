package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Squirtle = require "squirtle"

---@class AqueductAppState
local state = {
    times = 1,
    left = true,
    pillar = 20,
    ---@type "floor"|"wall"|"arches"
    mode = "floor",
    top = true,
    blocks = {
        bricks = "minecraft:stone_bricks",
        chiseled = "minecraft:chiseled_stone_bricks",
        lantern = "minecraft:lantern",
        stairs = "minecraft:stone_brick_stairs",
        stone = "minecraft:stone",
        torch = "minecraft:torch"
    }
}

local function printUsage()
    print("Usage:")
    print("aqueduct floor <times>")
    print("aqueduct wall <left|right> <times>")
    print("aqueduct arches top <times>")
    print("aqueduct arches bottom <left|right> <times> <pillar-height>")
end

---@param args table<string>
---@return AqueductAppState?
local function boot(args)
    if not arg[1] then
        return printUsage()
    end

    local mode = arg[1]
    local times = nil
    local left = true
    local top = true
    local pillar = nil

    if mode == "floor" then
        times = tonumber(args[2])
    elseif mode == "wall" then
        left = args[2] == "left"
        times = tonumber(args[3])
    elseif mode == "arches" then
        top = args[2] == "top"

        if top then
            times = tonumber(args[3])
        else
            left = args[3] == "left"
            times = tonumber(args[4])
            pillar = tonumber(args[5])

            if not pillar then
                return printUsage()
            end
        end
    else
        return printUsage()
    end

    if not times then
        return printUsage()
    end

    state.mode = mode
    state.left = left
    state.top = top
    state.times = times

    if pillar then
        state.pillar = pillar
    end

    return state
end

---@param state AqueductAppState
local function floorSequence(state)
    for _ = 1, state.times do
        Squirtle.placeDown(state.blocks.bricks)
        Squirtle.back()
        Squirtle.placeFront(state.blocks.chiseled)
    end
end

---@param state AqueductAppState
local function wallSequence(state)
    Squirtle.flipTurns = not state.left

    for _ = 1, state.times do
        Squirtle.placeFront(state.blocks.bricks)
        Squirtle.up()
        Squirtle.placeFront(state.blocks.torch)
        Squirtle.down(3)
        Squirtle.forward()
        Squirtle.around()
        -- top stairs
        Squirtle.placeUp(state.blocks.stairs)
        Squirtle.forward()
        Squirtle.placeUp(state.blocks.stone)
        -- bottom stairs
        Squirtle.down()
        Squirtle.placeUp(state.blocks.stairs)
        -- remaining stone line
        Squirtle.left()
        Squirtle.forward()
        Squirtle.up(3)

        for _ = 1, 7 do
            Squirtle.placeDown(state.blocks.stone)
            Squirtle.forward()
        end

        Squirtle.left()
    end

    Squirtle.flipTurns = false
end

---@param state AqueductAppState
local function archesTopSequence(state)
    for _ = 1, state.times do
        -- right side
        Squirtle.down()
        Squirtle.forward()
        Squirtle.placeUp(state.blocks.stairs)

        Squirtle.forward()
        Squirtle.placeUp(state.blocks.bricks)

        Squirtle.down()
        Squirtle.placeUp(state.blocks.stairs)

        -- center
        Squirtle.forward()
        Squirtle.down(4)

        for _ = 1, 6 do
            Squirtle.placeDown(state.blocks.bricks)
            Squirtle.up()
        end

        Squirtle.placeDown(state.blocks.bricks)

        -- left
        Squirtle.forward()
        Squirtle.down()
        Squirtle.placeUp(state.blocks.bricks)

        Squirtle.down()
        Squirtle.around()
        Squirtle.placeUp(state.blocks.stairs)

        Squirtle.back()
        Squirtle.up()
        Squirtle.placeUp(state.blocks.stairs)

        Squirtle.around()
        Squirtle.forward()
        Squirtle.up()
        Squirtle.forward(2)
    end
end

---@param state AqueductAppState
local function archesBottomSequence(state)
    Squirtle.flipTurns = not state.left

    for _ = 1, state.times do
        Squirtle.forward()
        Squirtle.down()
        Squirtle.placeUp(state.blocks.stairs)

        for _ = 1, 2 do
            Squirtle.forward()
            Squirtle.placeUp(state.blocks.bricks)
        end

        Squirtle.forward(2)
        Squirtle.placeDown(state.blocks.bricks)
        Squirtle.up()
        Squirtle.around()
        Squirtle.placeDown(state.blocks.stairs)
        Squirtle.around()
        Squirtle.back()
        Squirtle.down()
        Squirtle.placeUp(state.blocks.bricks)
        Squirtle.back()
        Squirtle.placeFront(state.blocks.bricks)
        Squirtle.down()
        Squirtle.placeUp(state.blocks.stairs)
        Squirtle.forward()
        Squirtle.down()
        Squirtle.placeUp(state.blocks.stairs)
        Squirtle.forward()
        Squirtle.down()
        Squirtle.placeUp(state.blocks.bricks)
        Squirtle.down()
        Squirtle.placeUp(state.blocks.stairs)
        Squirtle.forward()

        -- center pillar
        local depth = 0

        while Squirtle.tryWalk("down") do
            depth = depth + 1
        end

        for i = 1, depth + 4 do
            Squirtle.up()
            Squirtle.placeDown(state.blocks.bricks)

            if i == (depth + 4) - 2 then
                Squirtle.left()
                Squirtle.forward()
                Squirtle.up()
                Squirtle.placeUp(state.blocks.bricks)
                Squirtle.down()
                Squirtle.around()
                Squirtle.placeUp(state.blocks.stairs)
                Squirtle.around()
                Squirtle.back()
                Squirtle.right()
            end
        end

        Squirtle.left()
        Squirtle.placeFront(state.blocks.lantern)
        Squirtle.right()

        -- left side
        Squirtle.forward()
        Squirtle.placeDown(state.blocks.bricks)
        Squirtle.up()
        Squirtle.placeDown(state.blocks.stairs)
        Squirtle.forward()
        Squirtle.placeFront(state.blocks.bricks)
        Squirtle.down()
        Squirtle.placeUp(state.blocks.bricks)
        Squirtle.down()
        Squirtle.placeUp(state.blocks.bricks)
        Squirtle.down()
        Squirtle.around()
        Squirtle.placeUp(state.blocks.stairs)
        Squirtle.placeFront(state.blocks.bricks)
        Squirtle.down(2)
        Squirtle.forward()
        Squirtle.placeUp(state.blocks.stairs)
        Squirtle.back()
        Squirtle.up(2)
        Squirtle.back()
        Squirtle.up()
        Squirtle.placeUp(state.blocks.stairs)
        Squirtle.back()
        Squirtle.up()
        Squirtle.placeUp(state.blocks.bricks)
        Squirtle.back()
        Squirtle.placeUp(state.blocks.stairs)
        Squirtle.around()
        Squirtle.forward()
        Squirtle.up()
        Squirtle.forward(4)
    end

    Squirtle.flipTurns = false
end

---@param args table<string>
local function main(args)
    term.clear()
    term.setCursorPos(1, 1)
    print("[aqueduct v1.2.0] booting...")
    os.sleep(1)

    local state = boot(args)

    if not state then
        return nil
    end

    local modem = peripheral.find("modem")

    if not modem then
        error("no modem")
    end

    rednet.open(peripheral.getName(modem))
    rednet.host("aqueduct", os.getComputerLabel())

    local sequence = floorSequence

    if state.mode == "floor" then
        sequence = floorSequence
    elseif state.mode == "wall" then
        sequence = wallSequence
    elseif state.mode == "arches" then
        if state.top then
            sequence = archesTopSequence
        else
            sequence = archesBottomSequence
        end
    end

    Squirtle.simulate = true
    sequence(state)
    Squirtle.simulate = false

    local requiredFuel = Squirtle.results.steps
    local requiredItems = Squirtle.results.placed

    if state.mode == "arches" and state.top == false then
        requiredItems[state.blocks.bricks] = requiredItems[state.blocks.bricks] + (state.pillar * state.times)
    end

    Squirtle.refuel(requiredFuel)
    Squirtle.requireItems(requiredItems)

    local note = ""

    if state.mode == "floor" then
        note = "[note] make sure that where I am is the first chiseled lock to be placed"
    elseif state.mode == "wall" then
        note =
            "[note] make sure that the block in front of me is the first bricks block (with a torch on top) to be placed"
    elseif state.mode == "arches" then
        if state.top then
            note =
                "[note] make sure that the block in front of me is the first stairs block to be placed, and that the floor above me is already built."
        else
            note =
                "[note] make sure that the block in front of me is the first stairs block to be placed, and that the floor above me is already built."
        end
    end

    print(note)
    print(string.rep("-", term.getSize()))
    print("[note] if you see me doing nothing, I probably need something from you")
    print(string.rep("-", term.getSize()))
    print("[idle] waiting for signal from your PDA")

    while true do
        local _, message = rednet.receive("aqueduct")

        if message == "start" then
            break
        end
    end
    -- print("[idle] starting in 30 seconds. hit any key to skip waiting")
    -- timeout(30)
    print("[ready] starting to build!")
    sequence(state)
end

return main(arg)
