if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "computer"}
end

local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local Utils = require "lib.tools.utils"
local RemoteService = require "lib.systems.runtime.remote-service"
local XylophoneService = require "lib.systems.games.xylophone-service"

local isClient = arg[1] == "client"

---@param noteCount integer
local function server(noteCount)
    Utils.writeStartupFile(string.format("xylophone %d", noteCount))
    XylophoneService.run(noteCount)
end

---@param note integer
local function client(note)
    Utils.writeStartupFile(string.format("xylophone client %d", note))
    local xylophone = Rpc.nearest(XylophoneService)

    while true do
        EventLoop.pull("redstone")

        if redstone.getInput("back") then
            print("[played] note", note)
            xylophone.notePlayed(note)
        elseif redstone.getInput("left") or redstone.getInput("right") then
            print("[played] wrong note, resetting")
            xylophone.reset()
        end
    end
end

EventLoop.run(function()
    RemoteService.run({"xylophone"})
end, function()
    if isClient then
        local note = tonumber(arg[2])

        if type(note) ~= "number" then
            error("argument #2 (note) must be a number")
        end

        client(note)
    else
        local noteCount = tonumber(arg[1])

        if type(noteCount) ~= "number" then
            error("argument #1 (noteCount) must be a number")
        end

        server(noteCount)
    end
end)
