if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

package.path = package.path .. ";/app/turtle/?.lua"
local TurtleApi = require "lib.turtle.turtle-api"

-- required blocks (for layers = 4)
-- (64 + 33)x smooth_stone
-- 37x oak_loag
-- 29x stripped_oak_log
-- 10x redstone_lamp
-- 19x chests
-- 10x hopper
-- 10x comparator
-- 22x repeater
-- 13x redstone
-- 1x redstone_torch

---@class SiloAppState
local state = {
    ---@type "left" | "right"
    lampLocation = "left",
    ---@type "light" | "dark" | "basalt"
    theme = "light",
    layers = 4,
    blocks = {
        chest = "minecraft:chest",
        hopper = "minecraft:hopper",
        lamp = "minecraft:redstone_lamp",
        comparator = "minecraft:comparator",
        repeater = "minecraft:repeater",
        redstone = "minecraft:redstone",
        redstoneTorch = "minecraft:redstone_torch",
        -- variadic blocks
        filler = "minecraft:smooth_stone",
        backside = "minecraft:stripped_oak_log",
        support = "minecraft:oak_log"
    }
}

local function printUsage()
    print("Usage:")
    print("silo <side> <layers> [theme]")
    print("---")
    print("Example:")
    print("silo left 4 dark")
    print("silo right 1")
    print("available themes: light, dark, basalt")
end

---@param args table<string>
---@return SiloAppState?
local function boot(args)
    if not args[1] or not args[2] then
        printUsage()
        return nil
    end

    if string.lower(args[1]) == "right" then
        state.lampLocation = "right"
    elseif string.lower(args[1]) == "left" then
        state.lampLocation = "left"
    else
        printUsage()
        return nil
    end

    local layers = tonumber(args[2])

    if not layers then
        printUsage()
        return nil
    end

    state.layers = layers

    if not args[3] then
        state.theme = "light"
    elseif string.lower(args[3]) == "dark" then
        state.theme = "dark"
    elseif string.lower(args[3]) == "basalt" then
        state.theme = "basalt"
    end

    if state.theme == "basalt" then
        state.blocks.backside = "minecraft:deepslate_tiles"
        state.blocks.support = "minecraft:polished_basalt"
    elseif state.theme == "dark" then
        state.blocks.support = "minecraft:dark_oak_log"
    end

    return state
end

---@param state SiloAppState
local function sequence(state)
    local move = TurtleApi.move
    local turn = TurtleApi.turn
    local put = TurtleApi.put

    local restoreBreakable = TurtleApi.setBreakable(function()
        return true
    end)

    if state.lampLocation == "right" then
        turn("right")
        move("forward", 2)
        turn("left")
    elseif state.lampLocation == "left" then
        turn("right")
        move("forward", 4)
        turn("left")
        TurtleApi.setFlipTurns(true)
    end

    -- place center chests
    for _ = 1, (state.layers * 2) + 1 do
        put("front", state.blocks.chest)
        move("up")
    end

    -- place left support beam
    move("forward")
    turn("right")
    move("back", 2)
    put("top", state.blocks.support)
    move("down")
    put("top", state.blocks.support)

    -- place left hoppers
    for _ = 1, state.layers do
        move("down")
        put("top", state.blocks.support)
        put("front", state.blocks.hopper)
        move("down")
        put("top", state.blocks.support)
    end

    -- place bottom support beam
    move("down")
    put("top", state.blocks.support)
    turn("right")
    move("forward")
    move("up")

    -- right support
    turn("left")
    move("forward", 4)
    turn("left")
    move("forward")
    turn("left")

    for _ = 1, state.layers do
        put("front", state.blocks.hopper)
        move("up")
        put("bottom", state.blocks.support)
        move("up")
        put("bottom", state.blocks.support)
    end

    for _ = 1, 2 do
        move("up")
        put("bottom", state.blocks.support)
    end

    -- build top support
    move("forward", 2)

    for i = 1, 5 do
        put("front", state.blocks.support)

        if i ~= 5 then
            move("back")
        end
    end

    -- build right support incl. lights
    for _ = 1, (state.layers * 2) + 2 do
        move("down")
        put("top", state.blocks.support)
        put("front", state.blocks.lamp)
    end

    -- bottom piece of right support
    move("down")
    put("top", state.blocks.support)
    turn("left")
    move("forward")
    move("up")

    -- place remaining chests
    turn("right")
    move("forward", 3)
    turn("right")

    for _ = 1, state.layers do
        move("up")
        put("front", state.blocks.chest)
        move("up")
    end

    turn("left")
    move("forward", 2)
    turn("right")

    for i = 1, state.layers + 1 do
        put("front", state.blocks.chest)

        if i ~= state.layers + 1 then
            move("down", 2)
        end
    end

    -- move to backside
    turn("left")
    move("forward")
    move("down")
    turn("right")
    move("forward")
    move("forward")
    move("up")
    turn("left")
    move("back", 2)

    local function placeBacksideBlocks()
        put("bottom", state.blocks.filler)
        turn("right")
        move("forward")
        put("bottom", state.blocks.filler)
        move("back")
        turn("left")

        for _ = 1, 3 do
            move("forward")
            put("bottom", state.blocks.backside)
        end

        move("back")
    end

    -- place outer redstone circuit from chest to lamps
    ---@param isBottomLayer boolean
    local function placeOuterRedstone(isBottomLayer)
        local function placeBottomLayerBlock()
            move("down")
            put("bottom", state.blocks.filler)
            move("up")
        end

        turn("right")
        move("forward")
        put("bottom", state.blocks.filler)
        move("up")
        put("bottom", state.blocks.comparator)
        move("forward")
        put("bottom", state.blocks.filler)
        turn("right")
        move("forward")

        if isBottomLayer then
            placeBottomLayerBlock()
        end

        put("bottom", state.blocks.repeater)
        move("forward")
        put("bottom", state.blocks.filler)
        move("forward")

        if isBottomLayer then
            placeBottomLayerBlock()
        end

        put("bottom", state.blocks.repeater)
        move("forward")
        put("bottom", state.blocks.filler)
        turn("right")

        for _ = 1, 2 do
            move("forward")
            move("down")
            put("bottom", state.blocks.filler)
            move("up")
            put("bottom", state.blocks.redstone)
        end

        turn("right")
        move("forward", 2)
        placeBacksideBlocks()
    end

    -- place inner redstone circuit from chest to lamps
    local function placeInnerRedstone()
        move("back")
        turn("right")
        move("forward")
        put("bottom", state.blocks.filler)
        move("up")
        put("bottom", state.blocks.comparator)
        move("forward")
        put("bottom", state.blocks.filler)
        turn("right")
        move("forward")
        put("bottom", state.blocks.repeater)
        move("forward")
        put("bottom", state.blocks.filler)
        turn("right")
        move("forward")
        move("down")
        put("bottom", state.blocks.filler)
        move("up")
        put("bottom", state.blocks.repeater)
        move("forward")
        move("down")
        put("bottom", state.blocks.filler)
        move("up")
        put("bottom", state.blocks.filler)
        turn("right")
        move("forward")
        placeBacksideBlocks()
    end

    for i = 1, (state.layers * 2) + 1 do
        if i % 2 == 1 then
            placeOuterRedstone(i == 1)
        else
            placeInnerRedstone()
        end
    end

    -- build input chest
    move("forward")
    turn("left")
    move("back")
    move("down")
    put("front", state.blocks.hopper)
    turn("right")
    move("forward", 2)
    turn("left")
    move("forward")
    turn("left")
    put("front", state.blocks.hopper)

    -- redstone torch
    move("down")
    move("forward")
    turn("left")
    put("front", state.blocks.filler)
    move("down")
    put("top", state.blocks.redstoneTorch)

    -- "plus" construct
    move("forward", 2)
    move("up")
    put("bottom", state.blocks.filler)
    turn("back")
    move("up")
    put("bottom", state.blocks.repeater)
    move("back")
    put("bottom", state.blocks.filler)
    move("up")
    put("bottom", state.blocks.redstone)

    for _ = 1, 2 do
        move("forward")
        put("bottom", state.blocks.filler)
    end

    turn("back")
    move("up")

    -- input chest connection to topmost redstone lamp
    put("bottom", state.blocks.comparator)
    move("forward")
    put("bottom", state.blocks.redstone)
    turn("right")
    move("forward")
    move("down")
    put("bottom", state.blocks.filler)
    move("up")
    put("bottom", state.blocks.redstone)
    move("forward")
    put("bottom", state.blocks.repeater)
    move("forward")
    put("bottom", state.blocks.filler)
    move("forward")
    put("bottom", state.blocks.repeater)
    move("forward")
    put("bottom", state.blocks.filler)
    turn("right")
    move("forward")
    move("down")
    put("bottom", state.blocks.filler)
    move("up")
    put("bottom", state.blocks.repeater)
    move("forward")
    move("down")
    put("bottom", state.blocks.filler)
    move("up")
    put("bottom", state.blocks.filler)

    -- last row of chest backing blocks + input chest
    turn("right")
    move("forward")
    placeBacksideBlocks()
    move("forward", 2)
    turn("left")
    put("bottom", state.blocks.chest)

    -- go back home while placing last column of filler blocks
    move("back")
    turn("left")
    move("forward")
    move("down")

    for _ = 1, (state.layers * 2) + 1 do
        move("down")
        put("top", state.blocks.filler)
    end

    move("back")
    put("front", state.blocks.filler)
    turn("right")
    move("forward")
    move("down")
    move("forward", 2)
    move("up")

    -- done!
    if state.lampLocation == "right" then
        turn("back")
    else
        TurtleApi.setFlipTurns(false)
        turn("right")
        move("forward", 6)
        turn("right")
    end

    restoreBreakable()
end

print(string.format("[silo %s] booting...", version()))
local state = boot(arg)

if not state then
    return nil
end

-- [note] importante when making resumability easier to use:
-- orientate() relies on Simulation being inactive - otherwise placing the disk drive would be simulated :D

local results = TurtleApi.simulate(function()
    sequence(state)
end)

TurtleApi.requireItems(results.placed)
TurtleApi.refuelTo(results.steps)
print("[ok] all good now! building...")
sequence(state)
