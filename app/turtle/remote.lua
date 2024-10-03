package.path = package.path .. ";/?.lua"

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

local function main(args)
    print("[remote v1.1.0] booting...")
    local modem = peripheral.find("modem")

    if not modem then
        error("no modem")
    end

    rednet.open(peripheral.getName(modem))
    rednet.host("remote", os.getComputerLabel())
    print(string.rep("-", term.getSize()))
    print(
        "[note] make sure you run \"remote\" on your PDA while staying close to me (after that, you can move further away)")
    print(string.rep("-", term.getSize()))
    print("[ready] to receive commands!")
    parallel.waitForAny(function()
        while true do
            local _, message = rednet.receive("remote")
            local task = tasks[message]

            if task then
                task()
            end
        end
    end)

end

return main(arg)
