if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local EventLoop = require "lib.tools.event-loop"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local Rpc = require "lib.tools.rpc"
local SquirtleService = require "lib.squirtle.squirtle-service"

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

---@param args string[]
---@return PyramidAppState?
local function start(args)
    local width = tonumber(args[1])

    if not width or width % 2 == 0 then
        return printUsage()
    end

    local height = tonumber(args[2]) or math.ceil(width / 2)
    TurtleApi.configure({shulkerSides = {"top"}})
    local home = TurtleApi.locate()
    TurtleApi.orientate("disk-drive", {"top"})

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

---@param state PyramidAppState
local function main(state)
    TurtleApi.move()
    TurtleApi.turn("back")

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
        if TurtleApi.isFull() then
            TurtleApi.tryLoadShulkers()
        end

        TurtleApi.put("front", pickRandomBorderBlock(layer))
        TurtleApi.move("up")
        TurtleApi.turn("back")

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

                TurtleApi.put("bottom", block)
                TurtleApi.move()
            else
                TurtleApi.move("down")
                TurtleApi.put("front", pickRandomBorderBlock(layer))
                TurtleApi.move("up")
                TurtleApi.put("bottom", state.borderBlock)
                TurtleApi.move("back")
            end
        end
    end

    TurtleApi.tryLoadShulkers()
end

---@param state PyramidAppState
local function resume(state)
    TurtleApi.configure({shulkerSides = {"top"}})
    -- [todo] the position could actually be inferred during simulation. would make it so that gps is only required when starting.
    TurtleApi.locate()
    TurtleApi.orientate("disk-drive", {"top"})
end

---@param state PyramidAppState
local function finish(state)
    -- [todo] home is actually blocked by a block this program placed - either pick the one above as a goal or the one in front of it.
    if state.returnHome then
        print("[return] home")
        TurtleApi.navigate(state.home)
    end
end

print(string.format("[pyramid %s] booting...", version()))

EventLoop.run(function()
    EventLoop.runUntil("pyramid:stop", function()
        Rpc.host(SquirtleService)
    end)
end, function()
    local success, message = TurtleApi.runResumable("app/turtle/pyramid", arg, start, main, resume, finish)

    if success then
        EventLoop.queue("pyramid:stop")
    else
        print(message)
        SquirtleService.error = message
    end
end)

