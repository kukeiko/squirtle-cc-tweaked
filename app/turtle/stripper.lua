if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

local TurtleApi = require "lib.turtle.turtle-api"
local EventLoop = require "lib.tools.event-loop"

---@param stack ItemStack
---@return boolean
local function isUnstrippedLog(stack)
    return stack.tags["minecraft:logs"] and not string.find(stack.name, "stripped")
end

local function strip()
    while TurtleApi.selectPredicate(isUnstrippedLog) do
        TurtleApi.place("top")
        TurtleApi.use("top", "minecraft:diamond_axe")
        TurtleApi.dig("top")
    end
end

EventLoop.run(function()
    print(string.format("[stripper %s]", version()))
    os.sleep(1)
    term.clear()
    term.setCursorPos(1, 1)
    print("I can strip logs for you!\n")
    print("Just make sure I have a diamond pickaxe equipped, another one in my inventory, and that the space above me is empty.\n")
    print("Then just start putting logs into my inventory.")

    while true do
        strip()
        EventLoop.pull("turtle_inventory")
    end
end)
