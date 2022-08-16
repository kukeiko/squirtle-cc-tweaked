local digMap = {forward = turtle.dig, down = turtle.digDown, up = turtle.digUp}
local inspectMap = {forward = turtle.inspect, down = turtle.inspectDown, up = turtle.inspectUp}

---@param direction string
local function dig(direction)
    local success, block = inspectMap[direction]()

    while success and block.name:find("ore") do
        os.sleep(3)
        success, block = inspectMap[direction]()
    end

    while digMap[direction]() do
    end
end

local function main(args)
    local length = args[1] or 33
    print("[buddler v2.0.0] length = ", length)

    for i = 1, length do
        dig("forward")
        turtle.forward()
        dig("down")

        if i % 3 == 0 then
            dig("up")
            turtle.turnLeft()
            dig("forward")
            turtle.turnRight()
            turtle.turnRight()
            dig("forward")
            turtle.turnLeft()
        end
    end
end

main(arg)
