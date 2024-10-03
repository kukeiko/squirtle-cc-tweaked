package.path = package.path .. ";/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Utils = require "lib.common.utils"
local EventLoop = require "lib.common.event-loop"
local Squirtle = require "lib.squirtle"
local SquirtleState = require "lib.squirtle.state"
local Rpc = require "lib.common.rpc"
local SquirtleService = require "lib.squirtle.squirtle-service"
local AppState = require "lib.common.app-state"

---@class PyramidAppState
---@field width integer
---@field height integer
---@field seed integer
---@field home Vector
---@field facing integer
---@field fuel integer
---@field block string
---@field borderBlock string
---@field borderBlockAlt string
local state = {}

local function printUsage()
    print("Usage: pyramid <width> [<height>]")
    print(" - width must be odd ")
    print(" - height is optional ")
end

-- [todo] copied from dig app
---@param direction string
---@return boolean unloadedAll
local function loadIntoShulker(direction)
    local unloadedAll = true

    for slot = 1, 16 do
        local stack = Squirtle.getStack(slot)

        -- [todo] added disk_drive to exclusion for orientate to work better.
        -- orientate() should work even if a disk drive is inside a shulker box, but currently too eager
        -- to build the pyramid to test it
        if stack and not stack.name:match("shulker") and not stack.name:match("disk_drive") then
            Squirtle.select(slot)
            if not Squirtle.drop(direction) then
                unloadedAll = false
            end
        end
    end

    return unloadedAll
end

-- [todo] copied from dig app
-- [todo] move to Squirtle
---@return boolean unloadedAll
local function tryLoadShulkers()
    ---@type string?
    local placedSide = nil

    for slot = 1, 16 do
        local stack = Squirtle.getStack(slot)

        if stack and stack.name:match("shulker") then
            Squirtle.select(slot)
            placedSide = Squirtle.placeFrontTopOrBottom()

            if not placedSide then
                print("failed to place shulker, no space :(")
                -- [todo] bit of an issue returning false here - shulkers might have enough space for items,
                -- yet we effectively return "shulkers are full" just because we couldn't place it
                -- however, this should only be an issue when digging a 1-high layer
                return false
            else
                local unloadedAll = loadIntoShulker(placedSide)
                Squirtle.select(slot)
                Squirtle.mine(placedSide)

                if unloadedAll then
                    return true
                end
            end
        end
    end

    return false
end

---@param state PyramidAppState
local function sequence(state)
    Squirtle.move()
    Squirtle.turn("back")

    ---@param layer integer
    ---@return string
    local function pickRandomBorderBlock(layer)
        local chance = 1 - (layer * .075)

        if math.random() < chance then
            return state.borderBlockAlt
        else
            return state.borderBlock
        end
    end

    for layer = 1, state.height do
        if Squirtle.isFull() then
            tryLoadShulkers()
        end

        Squirtle.put("front", pickRandomBorderBlock(layer))
        Squirtle.move("up")
        Squirtle.turn("back")

        local length = state.width - (layer * 2)

        for column = 1, length do
            if column < length then
                local block = state.block

                if column <= 6 or column > length - 6 then
                    if layer == state.height then
                        if column > length - 6 then
                            block = pickRandomBorderBlock(layer + (length - column))
                        else
                            block = pickRandomBorderBlock(layer + column)
                        end
                    else
                        block = state.borderBlock
                    end
                end

                Squirtle.put("bottom", block)
                Squirtle.move()
            else
                Squirtle.move("down")
                Squirtle.put("front", pickRandomBorderBlock(layer))
                Squirtle.move("up")
                Squirtle.put("bottom", state.borderBlock)
                Squirtle.move("back")
            end
        end
    end

    tryLoadShulkers()
end

---@param args string[]
local function start(args)
    local width = tonumber(args[1])

    if not width or width % 2 == 0 then
        return printUsage()
    end

    local height = tonumber(args[2]) or math.ceil(width / 2)
    state.width = width
    state.height = height
    state.seed = os.epoch("utc")
    Squirtle.configure({orientate = "disk-drive", breakDirection = "top"})
    Squirtle.recover()
    state.home, state.facing = Squirtle.orientate(true)
    state.block = "minecraft:stone"
    state.borderBlock = "minecraft:stone_bricks"
    state.borderBlockAlt = "minecraft:mossy_stone_bricks"
    state.fuel = Squirtle.getNonInfiniteFuelLevel()
    Squirtle.simulate()
    math.randomseed(state.seed)
    sequence(state)
    SquirtleState.simulate = false
    local required = SquirtleState.results.placed
    required["computercraft:disk_drive"] = 1
    Squirtle.requireItems(required, true)
    AppState.save(state, "pyramid")
    Utils.writeStartupFile("pyramid", "resume")
    print("[ok] all good! rebooting...")
    os.sleep(1)
end

local function resume()
    ---@type PyramidAppState
    local state = AppState.load("pyramid")

    if not state then
        error("no pyramid app state file found")
    end

    Squirtle.configure({orientate = "disk-drive", breakDirection = "top"})
    Squirtle.recover()

    ---@type SimulationDetails
    local initial = {facing = state.facing, fuel = state.fuel}
    local _, facing = Squirtle.orientate(true)
    ---@type SimulationDetails
    local target = {facing = facing, fuel = Squirtle.getNonInfiniteFuelLevel()}

    Squirtle.simulate(initial, target)
    math.randomseed(state.seed)
    sequence(state)
    print("[complete] all done!")

    AppState.delete("pyramid")
    Utils.deleteStartupFile()
end

---@param args string[]
local function main(args)
    print("[pyramid v2.0.0-dev] booting...")

    EventLoop.run(function()
        Rpc.server(SquirtleService)
    end, function()
        local success, e = pcall(function(...)
            if args[1] == "resume" then
                resume()
            else
                start(args)
                resume()
            end
        end)

        if not success then
            print(e)
            SquirtleService.error = e
        end
    end)
end

main(arg)

