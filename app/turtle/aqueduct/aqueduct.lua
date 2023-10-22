package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Squirtle = require "squirtle.squirtle"
local SimulatableSquirtle = require "squirtle.simulated-squirtle"
local requireItems = require "squirtle.require-items"
local refuel = require "squirtle.refuel"
local timeout = require "utils.wait-timeout-or-until-key-event"

local cycles = tonumber(arg[1])
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
---@param squirtle SimulatableSquirtle
local function floorSequence(state, squirtle)
    for _ = 1, state.times do
        squirtle:place(state.blocks.bricks, "down")
        squirtle:back(1)
        squirtle:place(state.blocks.chiseled)
    end
end

---@param state AqueductAppState
---@param squirtle SimulatableSquirtle
local function wallSequence(state, squirtle)
    squirtle:flipTurns(not state.left)

    for _ = 1, state.times do
        squirtle:place(state.blocks.bricks)
        squirtle:up(1, true)
        squirtle:place(state.blocks.torch)
        squirtle:down(3, true)
        squirtle:forward(1, true)
        squirtle:around()
        -- top stairs
        squirtle:place(state.blocks.stairs, "up")
        squirtle:forward(1, true)
        squirtle:place(state.blocks.stone, "up")
        -- bottom stairs
        squirtle:down(1, true)
        squirtle:place(state.blocks.stairs, "up")
        -- remaining stone line
        squirtle:left()
        squirtle:forward(1, true)
        squirtle:up(3, true)

        for _ = 1, 7 do
            squirtle:place(state.blocks.stone, "down")
            squirtle:forward(1, true)
        end

        squirtle:left()
    end

    squirtle:flipTurns(not state.left)
end

---@param state AqueductAppState
---@param squirtle SimulatableSquirtle
local function archesTopSequence(state, squirtle)
    for _ = 1, state.times do
        -- right side
        squirtle:down(1, true)
        squirtle:forward(1, true)
        squirtle:place(state.blocks.stairs, "top")

        squirtle:forward(1, true)
        squirtle:place(state.blocks.bricks, "top")

        squirtle:down(1, true)
        squirtle:place(state.blocks.stairs, "top")

        -- center
        squirtle:forward(1, true)
        squirtle:down(4, true)

        for _ = 1, 6 do
            squirtle:place(state.blocks.bricks, "down")
            squirtle:up(1, true)
        end

        squirtle:place(state.blocks.bricks, "down")

        -- left
        squirtle:forward(1, true)
        squirtle:down(1, true)
        squirtle:place(state.blocks.bricks, "top")

        squirtle:down(1, true)
        squirtle:around()
        squirtle:place(state.blocks.stairs, "top")

        squirtle:back(1, true)
        squirtle:up(1, true)
        squirtle:place(state.blocks.stairs, "top")

        squirtle:around()
        squirtle:forward(1, true)
        squirtle:up(1, true)
        squirtle:forward(2, true)
    end
end

---@param state AqueductAppState
---@param squirtle SimulatableSquirtle
local function archesBottomSequence(state, squirtle)
    squirtle:flipTurns(not state.left)

    for _ = 1, state.times do
        squirtle:forward(1, true)
        squirtle:down(1, true)
        squirtle:place(state.blocks.stairs, "up")

        for _ = 1, 2 do
            squirtle:forward(1, true)
            squirtle:place(state.blocks.bricks, "up")
        end

        squirtle:forward(2, true)
        squirtle:place(state.blocks.bricks, "down")
        squirtle:up(1, true)
        squirtle:around()
        squirtle:place(state.blocks.stairs, "down")
        squirtle:around()
        squirtle:back(1, true)
        squirtle:down(1, true)
        squirtle:place(state.blocks.bricks, "up")
        squirtle:back(1, true)
        squirtle:place(state.blocks.bricks)
        squirtle:down(1, true)
        squirtle:place(state.blocks.stairs, "up")
        squirtle:forward(1, true)
        squirtle:down(1, true)
        squirtle:place(state.blocks.stairs, "up")
        squirtle:forward(1, true)
        squirtle:down(1, true)
        squirtle:place(state.blocks.bricks, "up")
        squirtle:down(1, true)
        squirtle:place(state.blocks.stairs, "up")
        squirtle:forward(1, true)

        -- center pillar
        local depth = 0

        while squirtle:down() do
            depth = depth + 1
        end

        for i = 1, depth + 4 do
            squirtle:up(1, true)
            squirtle:place(state.blocks.bricks, "down")

            if i == (depth + 4) - 2 then
                squirtle:left()
                squirtle:forward(1, true)
                squirtle:up(1, true)
                squirtle:place(state.blocks.bricks, "up")
                squirtle:down(1, true)
                squirtle:around()
                squirtle:place(state.blocks.stairs, "up")
                squirtle:around()
                squirtle:back(1, true)
                squirtle:right()
            end
        end

        squirtle:left()
        squirtle:place(state.blocks.lantern)
        squirtle:right()

        -- left side

        squirtle:forward(1, true)
        squirtle:place(state.blocks.bricks, "down")
        squirtle:up(1, true)
        squirtle:place(state.blocks.stairs, "down")
        squirtle:forward(1, true)
        squirtle:place(state.blocks.bricks)
        squirtle:down(1, true)
        squirtle:place(state.blocks.bricks, "up")
        squirtle:down(1, true)
        squirtle:place(state.blocks.bricks, "up")
        squirtle:down(1, true)
        squirtle:around()
        squirtle:place(state.blocks.stairs, "up")
        squirtle:place(state.blocks.bricks)
        squirtle:down(2, true)
        squirtle:forward(1, true)
        squirtle:place(state.blocks.stairs, "up")
        squirtle:back(1, true)
        squirtle:up(2, true)
        squirtle:back(1, true)
        squirtle:up(1, true)
        squirtle:place(state.blocks.stairs, "up")
        squirtle:back(1, true)
        squirtle:up(1, true)
        squirtle:place(state.blocks.bricks, "up")
        squirtle:back(1, true)
        squirtle:place(state.blocks.stairs, "up")
        squirtle:around()
        squirtle:forward(1, true)
        squirtle:up(1, true)
        squirtle:forward(4, true)
    end

    squirtle:flipTurns(not state.left)
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

    local squirtle = SimulatableSquirtle:new(Squirtle:new())
    squirtle.simulate = true
    sequence(state, squirtle)
    squirtle.simulate = false

    local requiredFuel = squirtle.timesMoved
    local requiredItems = squirtle.blocksPlaced

    if state.mode == "arches" and state.top == false then
        requiredItems[state.blocks.bricks] = requiredItems[state.blocks.bricks] + (state.pillar * state.times)
    end

    refuel(requiredFuel)
    requireItems(requiredItems)

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
    sequence(state, squirtle)
end

return main(arg)
