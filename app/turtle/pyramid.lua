package.path = package.path .. ";/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Utils = require "lib.common.utils"
local EventLoop = require "lib.common.event-loop"
local SquirtleState = require "lib.squirtle.state"
local Squirtle = require "lib.squirtle.squirtle-api"
local Rpc = require "lib.common.rpc"
local SquirtleService = require "lib.squirtle.squirtle-service"
local AppState = require "lib.common.app-state"

---@class PyramidAppState
---@field width integer
---@field height integer
---@field home Vector
---@field returnHome boolean
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
            -- [todo] for pyramid app, it is not allowed to place in front as it might be facing towards a pyramid lane of another turtle
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

    -- [todo] returning home needs to be part of Squirtle.runResumable() as it is incompatible with simulation.
    -- for now its fine as long as the turtle doesn't reboot during returning home.
    if state.returnHome then
        if not SquirtleState.simulate then
            print("[return] home")
        end

        Squirtle.navigate(state.home)
    end
end

---@param args string[]
---@return PyramidAppState?
local function start(args)
    local width = tonumber(args[1])

    if not width or width % 2 == 0 then
        return printUsage()
    end

    local height = tonumber(args[2]) or math.ceil(width / 2)
    local home = Squirtle.locate(true)
    Squirtle.orientate(true)

    ---@type PyramidAppState
    local state = {
        width = width,
        height = height,
        block = "minecraft:stone",
        borderBlock = "minecraft:stone_bricks",
        borderBlockAlt = "minecraft:mossy_stone_bricks",
        home = home,
        returnHome = args[2] == "home" or args[3] == "home"
    }

    return state
end

---@param args string[]
local function main(args)
    print("[pyramid v3.0.0-dev] booting...")

    EventLoop.run(function()
        EventLoop.runUntil("pyramid:stop", function()
            Rpc.server(SquirtleService)
        end)
    end, function()
        local success, message = Squirtle.runResumable("app/turtle/pyramid", args, start, sequence,
                                                       {orientate = "disk-drive", breakDirection = "top"})

        if success then
            EventLoop.queue("pyramid:stop")
        else
            print(message)
            SquirtleService.error = message
        end
    end)
end

main(arg)

