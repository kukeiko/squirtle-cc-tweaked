if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

local TurtleApi = require "lib.apis.turtle.turtle-api"

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
        TurtleApi.put("bottom", state.blocks.bricks)
        TurtleApi.move("back")
        TurtleApi.put("front", state.blocks.chiseled)
    end
end

---@param state AqueductAppState
local function wallSequence(state)
    TurtleApi.setFlipTurns(not state.left)

    for _ = 1, state.times do
        TurtleApi.put("front", state.blocks.bricks)
        TurtleApi.move("up")
        TurtleApi.put("front", state.blocks.torch)
        TurtleApi.move("down", 3)
        TurtleApi.move("forward")
        TurtleApi.turn("back")
        -- top stairs
        TurtleApi.put("top", state.blocks.stairs)
        TurtleApi.move("forward")
        TurtleApi.put("top", state.blocks.stone)
        -- bottom stairs
        TurtleApi.move("down")
        TurtleApi.put("top", state.blocks.stairs)
        -- remaining stone line
        TurtleApi.turn("left")
        TurtleApi.move("forward")
        TurtleApi.move("up", 3)

        for _ = 1, 7 do
            TurtleApi.put("bottom", state.blocks.stone)
            TurtleApi.move("forward")
        end

        TurtleApi.turn("left")
    end

    TurtleApi.setFlipTurns(false)
end

---@param state AqueductAppState
local function archesTopSequence(state)
    for _ = 1, state.times do
        -- right side
        TurtleApi.move("down")
        TurtleApi.move("forward")
        TurtleApi.put("top", state.blocks.stairs)

        TurtleApi.move("forward")
        TurtleApi.put("top", state.blocks.bricks)

        TurtleApi.move("down")
        TurtleApi.put("top", state.blocks.stairs)

        -- center
        TurtleApi.move("forward")
        TurtleApi.move("down", 4)

        for _ = 1, 6 do
            TurtleApi.put("bottom", state.blocks.bricks)
            TurtleApi.move("up")
        end

        TurtleApi.put("bottom", state.blocks.bricks)

        -- left
        TurtleApi.move("forward")
        TurtleApi.move("down")
        TurtleApi.put("top", state.blocks.bricks)

        TurtleApi.move("down")
        TurtleApi.turn("back")
        TurtleApi.put("top", state.blocks.stairs)

        TurtleApi.move("back")
        TurtleApi.move("up")
        TurtleApi.put("top", state.blocks.stairs)

        TurtleApi.turn("back")
        TurtleApi.move("forward")
        TurtleApi.move("up")
        TurtleApi.move("forward", 2)
    end
end

---@param state AqueductAppState
local function archesBottomSequence(state)
    TurtleApi.setFlipTurns(not state.left)

    for _ = 1, state.times do
        TurtleApi.move("forward")
        TurtleApi.move("down")
        TurtleApi.put("top", state.blocks.stairs)

        for _ = 1, 2 do
            TurtleApi.move("forward")
            TurtleApi.put("top", state.blocks.bricks)
        end

        TurtleApi.move("forward", 2)
        TurtleApi.put("bottom", state.blocks.bricks)
        TurtleApi.move("up")
        TurtleApi.turn("back")
        TurtleApi.put("bottom", state.blocks.stairs)
        TurtleApi.turn("back")
        TurtleApi.move("back")
        TurtleApi.move("down")
        TurtleApi.put("top", state.blocks.bricks)
        TurtleApi.move("back")
        TurtleApi.put("front", state.blocks.bricks)
        TurtleApi.move("down")
        TurtleApi.put("top", state.blocks.stairs)
        TurtleApi.move("forward")
        TurtleApi.move("down")
        TurtleApi.put("top", state.blocks.stairs)
        TurtleApi.move("forward")
        TurtleApi.move("down")
        TurtleApi.put("top", state.blocks.bricks)
        TurtleApi.move("down")
        TurtleApi.put("top", state.blocks.stairs)
        TurtleApi.move("forward")

        -- center pillar
        local depth = 0

        while TurtleApi.tryWalk("down") do
            depth = depth + 1
        end

        for i = 1, depth + 4 do
            TurtleApi.move("up")
            TurtleApi.put("bottom", state.blocks.bricks)

            if i == (depth + 4) - 2 then
                TurtleApi.turn("left")
                TurtleApi.move("forward")
                TurtleApi.move("up")
                TurtleApi.put("top", state.blocks.bricks)
                TurtleApi.move("down")
                TurtleApi.turn("back")
                TurtleApi.put("top", state.blocks.stairs)
                TurtleApi.turn("back")
                TurtleApi.move("back")
                TurtleApi.turn("right")
            end
        end

        TurtleApi.turn("left")
        TurtleApi.put("front", state.blocks.lantern)
        TurtleApi.turn("right")

        -- left side
        TurtleApi.move("forward")
        TurtleApi.put("bottom", state.blocks.bricks)
        TurtleApi.move("up")
        TurtleApi.put("bottom", state.blocks.stairs)
        TurtleApi.move("forward")
        TurtleApi.put("front", state.blocks.bricks)
        TurtleApi.move("down")
        TurtleApi.put("top", state.blocks.bricks)
        TurtleApi.move("down")
        TurtleApi.put("top", state.blocks.bricks)
        TurtleApi.move("down")
        TurtleApi.turn("back")
        TurtleApi.put("top", state.blocks.stairs)
        TurtleApi.put("front", state.blocks.bricks)
        TurtleApi.move("down", 2)
        TurtleApi.move("forward")
        TurtleApi.put("top", state.blocks.stairs)
        TurtleApi.move("back")
        TurtleApi.move("up", 2)
        TurtleApi.move("back")
        TurtleApi.move("up")
        TurtleApi.put("top", state.blocks.stairs)
        TurtleApi.move("back")
        TurtleApi.move("up")
        TurtleApi.put("top", state.blocks.bricks)
        TurtleApi.move("back")
        TurtleApi.put("top", state.blocks.stairs)
        TurtleApi.turn("back")
        TurtleApi.move("forward")
        TurtleApi.move("up")
        TurtleApi.move("forward", 4)
    end

    TurtleApi.setFlipTurns(false)
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

    local results = TurtleApi.simulate(function()
        sequence(state)
    end)

    local requiredFuel = results.steps
    local requiredItems = results.placed

    if state.mode == "arches" and state.top == false then
        requiredItems[state.blocks.bricks] = requiredItems[state.blocks.bricks] + (state.pillar * state.times)
    end

    TurtleApi.refuelTo(requiredFuel)
    TurtleApi.requireItems(requiredItems)

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
