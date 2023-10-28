local digMap = {forward = turtle.dig, down = turtle.digDown, up = turtle.digUp}
local inspectMap = {forward = turtle.inspect, down = turtle.inspectDown, up = turtle.inspectUp}

---@param direction string
local function dig(direction)
    local success, block = inspectMap[direction]()

    while success and block.name:find("ore") do
        os.sleep(1)
        success, block = inspectMap[direction]()
    end

    while digMap[direction]() do
    end
end

local function selectTorch()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            local item = turtle.getItemDetail(slot)
            if item and item.name == "minecraft:torch" then
                turtle.select(slot)
                return true
            end
        end
    end

    return false
end

local function digUpLeftRight()
    dig("up")
    turtle.turnLeft()
    dig("forward")
    turtle.turnRight()
    turtle.turnRight()
    dig("forward")
    turtle.turnLeft()
end

local function forward()
    dig("forward")
    turtle.forward()
    dig("down")
end

local function cycle()
    for _ = 1, 3 do
        for step = 1, 3 do
            forward()

            if step == 3 then
                digUpLeftRight()
            end
        end
    end

    if selectTorch() then
        turtle.placeDown()
        turtle.select(1)
    end
end

local function main(args)
    print("[buddler v2.2.0] booting...")
    turtle.select(1)
    local cycles = args[1] or 11
    print("[info] doing", cycles, "cycles")

    for _ = 1, cycles do
        cycle()
    end
end

main(arg)
