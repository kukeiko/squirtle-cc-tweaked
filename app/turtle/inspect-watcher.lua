if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "computer"}
end

local Utils = require "lib.tools.utils"
local TurtleApi = require "lib.apis.turtle.turtle-api"

local blockSide = arg[1]
local signalSide = arg[2]
local item = arg[3]
local message = arg[4]

if not blockSide or not signalSide or not item or not message then
    print("Usage:")
    print("inspect-watcher <block-side> <signal-side> <item> <message>")
    return
end

Utils.writeStartupFile(string.format("inspect-watcher %s %s %s \\\"%s\\\"", blockSide, signalSide, item or "", message or ""))

term.clear()
term.setCursorPos(1, 1)
print(message)

while true do
    redstone.setOutput(signalSide, TurtleApi.probe(blockSide, item) == nil)
    os.sleep(1)
end
