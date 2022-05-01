package.path = package.path .. ";/lib/?.lua"

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
    print("[remote-control v 1.0.0] booting...")
    local modem = peripheral.find("modem")

    if not modem then
        error("no modem")
    end

    rednet.open(peripheral.getName(modem))
    rednet.host("remote-control", os.getComputerLabel())

    local taskQueue = {}

    parallel.waitForAny(function()
        while true do
            local _, message = rednet.receive("remote-control")
            print("got message", message, "from", _)
            local task = tasks[message]

            if task then
                task()
            end
        end
    end)

end

return main(arg)
