if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

print(string.format("[remote-control %s]", version()))

---@type table<integer, function>
local tasks = {
    [keys.w] = function()
        while not turtle.forward() do
            turtle.dig()
        end
    end,
    [keys.a] = function()
        turtle.turnLeft()
    end,
    [keys.s] = function()
        turtle.back()
    end,
    [keys.d] = function()
        turtle.turnRight()
    end,
    [keys.space] = function()
        while not turtle.up() do
            turtle.digUp()
        end
    end,
    [keys.leftShift] = function()
        while not turtle.down() do
            turtle.digDown()
        end
    end,
    [keys.e] = function()
        turtle.dig()
    end,
    [keys.r] = function()
        turtle.digUp()
    end,
    [keys.f] = function()
        turtle.digDown()
    end
}

local modem = peripheral.find("modem")

if not modem then
    error("no modem")
end

rednet.open(peripheral.getName(modem))
rednet.host("remote-control", os.getComputerLabel())
print(string.rep("-", term.getSize()))
print("[note] make sure you run \"remote-control\" on your PDA while staying close to me (after that, you can move further away)")
print(string.rep("-", term.getSize()))
print("[ready] to receive commands!")

parallel.waitForAny(function()
    while true do
        local _, message = rednet.receive("remote-control")
        local task = tasks[message]

        if task then
            task()
        end
    end
end)
