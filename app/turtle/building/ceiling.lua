if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local TurtleApi = require "lib.turtle.turtle-api"
local TurtleService = require "lib.turtle.turtle-service"
local Resumable = require "lib.turtle.resumable"
local EditEntity = require "lib.ui.edit-entity"

---@return string
local function promptBlock()
    term.clear()
    term.setCursorPos(1, 1)
    print("[prompt] put the block to use in my first slot, then confirm with enter.")

    while EventLoop.pullKeys({keys.enter, keys.numPadEnter}) do
        local stack = TurtleApi.getStack(1)

        if stack then
            return stack.name
        end
    end
end

EventLoop.run(function()
    EventLoop.runUntil("ceiling:stop", function()
        Rpc.host(TurtleService)
    end)
end, function()
    local resumable = Resumable.new("ceiling")

    resumable:setStart(function(_, options)
        local editEntity = EditEntity.new("Options")
        editEntity:addInteger("depth", "Depth", {validate = EditEntity.greaterZero})
        editEntity:addInteger("width", "Width", {validate = EditEntity.notZero})
        ---@class CeilingAppArguments
        ---@field depth integer
        ---@field width integer
        local arguments = editEntity:run({}, "data/app/ceiling-options.json")

        ---@class CeilingAppState
        local state = {
            depth = arguments.depth,
            width = arguments.width,
            block = promptBlock(),
            home = TurtleApi.getPosition(),
            facing = TurtleApi.orientate("disk-drive")
        }
        options.requireFuel = true
        options.requireItems = true
        Utils.writeStartupFile("ceiling")

        return state
    end)

    resumable:setResume(function()
        TurtleApi.orientate("disk-drive")
    end)

    ---@param state CeilingAppState
    resumable:addSimulatableMain("ceiling", function(state)
        TurtleApi.buildCeiling(state.depth, state.width, state.block)
    end)

    resumable:setFinish(function()
        Utils.deleteStartupFile()
    end)

    local success, message = pcall(function(...)
        resumable:run(arg)
    end)

    if success then
        EventLoop.queue("ceiling:stop")
    else
        print(message)
        TurtleService.error = message
    end
end)
