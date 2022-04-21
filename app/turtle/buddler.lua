local function digFront()
    local success, front = turtle.inspect()

    while success and front.name:find("ore") do
        os.sleep(3)
        success, front = turtle.inspect()
    end

    while turtle.dig() do
    end
end

local function digDown()
    local success, bottom = turtle.inspectDown()

    while success and bottom.name:find("ore") do
        os.sleep(3)
        success, bottom = turtle.inspectDown()
    end

    turtle.digDown()
end

local function main(args)
    local length = args[1] or 32

    print("length =", length)

    for i = 1, length do
        digFront()
        turtle.forward()
        digDown()

        if i % 3 == 0 then
            turtle.turnLeft()
            digFront()
            turtle.turnRight()
            turtle.turnRight()
            digFront()
            turtle.turnLeft()
        end
    end
end

main(arg)
