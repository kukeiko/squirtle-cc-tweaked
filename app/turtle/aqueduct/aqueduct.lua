package.path = package.path .. ";/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Squirtle = require "lib.squirtle"
local SquirtleState = require "lib.squirtle.state"

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
        Squirtle.put("bottom", state.blocks.bricks)
        Squirtle.move("back")
        Squirtle.put("front", state.blocks.chiseled)
    end
end

---@param state AqueductAppState
local function wallSequence(state)
    SquirtleState.flipTurns = not state.left

    for _ = 1, state.times do
        Squirtle.put("front", state.blocks.bricks)
        Squirtle.move("up")
        Squirtle.put("front", state.blocks.torch)
        Squirtle.move("down", 3)
        Squirtle.move("forward")
        Squirtle.turn("back")
        -- top stairs
        Squirtle.put("top", state.blocks.stairs)
        Squirtle.move("forward")
        Squirtle.put("top", state.blocks.stone)
        -- bottom stairs
        Squirtle.move("down")
        Squirtle.put("top", state.blocks.stairs)
        -- remaining stone line
        Squirtle.turn("left")
        Squirtle.move("forward")
        Squirtle.move("up", 3)

        for _ = 1, 7 do
            Squirtle.put("bottom", state.blocks.stone)
            Squirtle.move("forward")
        end

        Squirtle.turn("left")
    end

    SquirtleState.flipTurns = false
end

---@param state AqueductAppState
local function archesTopSequence(state)
    for _ = 1, state.times do
        -- right side
        Squirtle.move("down")
        Squirtle.move("forward")
        Squirtle.put("top", state.blocks.stairs)

        Squirtle.move("forward")
        Squirtle.put("top", state.blocks.bricks)

        Squirtle.move("down")
        Squirtle.put("top", state.blocks.stairs)

        -- center
        Squirtle.move("forward")
        Squirtle.move("down", 4)

        for _ = 1, 6 do
            Squirtle.put("bottom", state.blocks.bricks)
            Squirtle.move("up")
        end

        Squirtle.put("bottom", state.blocks.bricks)

        -- left
        Squirtle.move("forward")
        Squirtle.move("down")
        Squirtle.put("top", state.blocks.bricks)

        Squirtle.move("down")
        Squirtle.turn("back")
        Squirtle.put("top", state.blocks.stairs)

        Squirtle.move("back")
        Squirtle.move("up")
        Squirtle.put("top", state.blocks.stairs)

        Squirtle.turn("back")
        Squirtle.move("forward")
        Squirtle.move("up")
        Squirtle.move("forward", 2)
    end
end

---@param state AqueductAppState
local function archesBottomSequence(state)
    SquirtleState.flipTurns = not state.left

    for _ = 1, state.times do
        Squirtle.move("forward")
        Squirtle.move("down")
        Squirtle.put("top", state.blocks.stairs)

        for _ = 1, 2 do
            Squirtle.move("forward")
            Squirtle.put("top", state.blocks.bricks)
        end

        Squirtle.move("forward", 2)
        Squirtle.put("bottom", state.blocks.bricks)
        Squirtle.move("up")
        Squirtle.turn("back")
        Squirtle.put("bottom", state.blocks.stairs)
        Squirtle.turn("back")
        Squirtle.move("back")
        Squirtle.move("down")
        Squirtle.put("top", state.blocks.bricks)
        Squirtle.move("back")
        Squirtle.put("front", state.blocks.bricks)
        Squirtle.move("down")
        Squirtle.put("top", state.blocks.stairs)
        Squirtle.move("forward")
        Squirtle.move("down")
        Squirtle.put("top", state.blocks.stairs)
        Squirtle.move("forward")
        Squirtle.move("down")
        Squirtle.put("top", state.blocks.bricks)
        Squirtle.move("down")
        Squirtle.put("top", state.blocks.stairs)
        Squirtle.move("forward")

        -- center pillar
        local depth = 0

        while Squirtle.tryWalk("down") do
            depth = depth + 1
        end

        for i = 1, depth + 4 do
            Squirtle.move("up")
            Squirtle.put("bottom", state.blocks.bricks)

            if i == (depth + 4) - 2 then
                Squirtle.turn("left")
                Squirtle.move("forward")
                Squirtle.move("up")
                Squirtle.put("top", state.blocks.bricks)
                Squirtle.move("down")
                Squirtle.turn("back")
                Squirtle.put("top", state.blocks.stairs)
                Squirtle.turn("back")
                Squirtle.move("back")
                Squirtle.turn("right")
            end
        end

        Squirtle.turn("left")
        Squirtle.put("front", state.blocks.lantern)
        Squirtle.turn("right")

        -- left side
        Squirtle.move("forward")
        Squirtle.put("bottom", state.blocks.bricks)
        Squirtle.move("up")
        Squirtle.put("bottom", state.blocks.stairs)
        Squirtle.move("forward")
        Squirtle.put("front", state.blocks.bricks)
        Squirtle.move("down")
        Squirtle.put("top", state.blocks.bricks)
        Squirtle.move("down")
        Squirtle.put("top", state.blocks.bricks)
        Squirtle.move("down")
        Squirtle.turn("back")
        Squirtle.put("top", state.blocks.stairs)
        Squirtle.put("front", state.blocks.bricks)
        Squirtle.move("down", 2)
        Squirtle.move("forward")
        Squirtle.put("top", state.blocks.stairs)
        Squirtle.move("back")
        Squirtle.move("up", 2)
        Squirtle.move("back")
        Squirtle.move("up")
        Squirtle.put("top", state.blocks.stairs)
        Squirtle.move("back")
        Squirtle.move("up")
        Squirtle.put("top", state.blocks.bricks)
        Squirtle.move("back")
        Squirtle.put("top", state.blocks.stairs)
        Squirtle.turn("back")
        Squirtle.move("forward")
        Squirtle.move("up")
        Squirtle.move("forward", 4)
    end

    SquirtleState.flipTurns = false
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

    SquirtleState.simulate = true
    sequence(state)
    SquirtleState.simulate = false

    local requiredFuel = SquirtleState.results.steps
    local requiredItems = SquirtleState.results.placed

    if state.mode == "arches" and state.top == false then
        requiredItems[state.blocks.bricks] = requiredItems[state.blocks.bricks] + (state.pillar * state.times)
    end

    Squirtle.refuelTo(requiredFuel)
    Squirtle.requireItems(requiredItems)

    local note = ""

    if state.mode == "floor" then
        note = "[note] make sure that where I am is the first chiseled lock to be placed"
    elseif state.mode == "wall" then
        note = "[note] make sure that the block in front of me is the first bricks block (with a torch on top) to be placed"
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
