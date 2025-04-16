if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Turtle = require "lib.squirtle.squirtle-api"

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
        Turtle.put("bottom", state.blocks.bricks)
        Turtle.move("back")
        Turtle.put("front", state.blocks.chiseled)
    end
end

---@param state AqueductAppState
local function wallSequence(state)
    Turtle.setFlipTurns(not state.left)

    for _ = 1, state.times do
        Turtle.put("front", state.blocks.bricks)
        Turtle.move("up")
        Turtle.put("front", state.blocks.torch)
        Turtle.move("down", 3)
        Turtle.move("forward")
        Turtle.turn("back")
        -- top stairs
        Turtle.put("top", state.blocks.stairs)
        Turtle.move("forward")
        Turtle.put("top", state.blocks.stone)
        -- bottom stairs
        Turtle.move("down")
        Turtle.put("top", state.blocks.stairs)
        -- remaining stone line
        Turtle.turn("left")
        Turtle.move("forward")
        Turtle.move("up", 3)

        for _ = 1, 7 do
            Turtle.put("bottom", state.blocks.stone)
            Turtle.move("forward")
        end

        Turtle.turn("left")
    end

    Turtle.setFlipTurns(false)
end

---@param state AqueductAppState
local function archesTopSequence(state)
    for _ = 1, state.times do
        -- right side
        Turtle.move("down")
        Turtle.move("forward")
        Turtle.put("top", state.blocks.stairs)

        Turtle.move("forward")
        Turtle.put("top", state.blocks.bricks)

        Turtle.move("down")
        Turtle.put("top", state.blocks.stairs)

        -- center
        Turtle.move("forward")
        Turtle.move("down", 4)

        for _ = 1, 6 do
            Turtle.put("bottom", state.blocks.bricks)
            Turtle.move("up")
        end

        Turtle.put("bottom", state.blocks.bricks)

        -- left
        Turtle.move("forward")
        Turtle.move("down")
        Turtle.put("top", state.blocks.bricks)

        Turtle.move("down")
        Turtle.turn("back")
        Turtle.put("top", state.blocks.stairs)

        Turtle.move("back")
        Turtle.move("up")
        Turtle.put("top", state.blocks.stairs)

        Turtle.turn("back")
        Turtle.move("forward")
        Turtle.move("up")
        Turtle.move("forward", 2)
    end
end

---@param state AqueductAppState
local function archesBottomSequence(state)
    Turtle.setFlipTurns(not state.left)

    for _ = 1, state.times do
        Turtle.move("forward")
        Turtle.move("down")
        Turtle.put("top", state.blocks.stairs)

        for _ = 1, 2 do
            Turtle.move("forward")
            Turtle.put("top", state.blocks.bricks)
        end

        Turtle.move("forward", 2)
        Turtle.put("bottom", state.blocks.bricks)
        Turtle.move("up")
        Turtle.turn("back")
        Turtle.put("bottom", state.blocks.stairs)
        Turtle.turn("back")
        Turtle.move("back")
        Turtle.move("down")
        Turtle.put("top", state.blocks.bricks)
        Turtle.move("back")
        Turtle.put("front", state.blocks.bricks)
        Turtle.move("down")
        Turtle.put("top", state.blocks.stairs)
        Turtle.move("forward")
        Turtle.move("down")
        Turtle.put("top", state.blocks.stairs)
        Turtle.move("forward")
        Turtle.move("down")
        Turtle.put("top", state.blocks.bricks)
        Turtle.move("down")
        Turtle.put("top", state.blocks.stairs)
        Turtle.move("forward")

        -- center pillar
        local depth = 0

        while Turtle.tryWalk("down") do
            depth = depth + 1
        end

        for i = 1, depth + 4 do
            Turtle.move("up")
            Turtle.put("bottom", state.blocks.bricks)

            if i == (depth + 4) - 2 then
                Turtle.turn("left")
                Turtle.move("forward")
                Turtle.move("up")
                Turtle.put("top", state.blocks.bricks)
                Turtle.move("down")
                Turtle.turn("back")
                Turtle.put("top", state.blocks.stairs)
                Turtle.turn("back")
                Turtle.move("back")
                Turtle.turn("right")
            end
        end

        Turtle.turn("left")
        Turtle.put("front", state.blocks.lantern)
        Turtle.turn("right")

        -- left side
        Turtle.move("forward")
        Turtle.put("bottom", state.blocks.bricks)
        Turtle.move("up")
        Turtle.put("bottom", state.blocks.stairs)
        Turtle.move("forward")
        Turtle.put("front", state.blocks.bricks)
        Turtle.move("down")
        Turtle.put("top", state.blocks.bricks)
        Turtle.move("down")
        Turtle.put("top", state.blocks.bricks)
        Turtle.move("down")
        Turtle.turn("back")
        Turtle.put("top", state.blocks.stairs)
        Turtle.put("front", state.blocks.bricks)
        Turtle.move("down", 2)
        Turtle.move("forward")
        Turtle.put("top", state.blocks.stairs)
        Turtle.move("back")
        Turtle.move("up", 2)
        Turtle.move("back")
        Turtle.move("up")
        Turtle.put("top", state.blocks.stairs)
        Turtle.move("back")
        Turtle.move("up")
        Turtle.put("top", state.blocks.bricks)
        Turtle.move("back")
        Turtle.put("top", state.blocks.stairs)
        Turtle.turn("back")
        Turtle.move("forward")
        Turtle.move("up")
        Turtle.move("forward", 4)
    end

    Turtle.setFlipTurns(false)
end

---@param args table<string>
local function main(args)
    term.clear()
    term.setCursorPos(1, 1)
    print(string.format("[aqueduct %s] booting...", version()))
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

    Turtle.beginSimulation()
    sequence(state)
    local results = Turtle.endSimulation()
    local requiredFuel = results.steps
    local requiredItems = results.placed

    if state.mode == "arches" and state.top == false then
        requiredItems[state.blocks.bricks] = requiredItems[state.blocks.bricks] + (state.pillar * state.times)
    end

    Turtle.refuelTo(requiredFuel)
    Turtle.requireItems(requiredItems)

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
