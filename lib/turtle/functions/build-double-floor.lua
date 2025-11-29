---@param TurtleApi TurtleApi
---@param depth integer
---@param width integer
---@param block string
---@param above? boolean
return function(TurtleApi, depth, width, block, above)
    assert(depth > 0, "depth must be greater than 0")
    assert(width ~= 0, "width can't be 0")
    local side = above and "top" or "bottom"
    local left = "left"
    local right = "right"

    if width < 0 then
        left = "right"
        right = "left"
        width = math.abs(width)
    end

    TurtleApi.turn("back")

    for line = 1, width do
        for column = 1, depth do
            TurtleApi.put(side, block)

            if column ~= depth then
                TurtleApi.move("back")
                TurtleApi.put("front", block)
            elseif line ~= width then
                local direction = line % 2 == 1 and right or left
                TurtleApi.turn(direction)
                TurtleApi.move("back")
                TurtleApi.put("front", block)
                TurtleApi.turn(direction)
            elseif line == width then
                TurtleApi.move(above and "down" or "up")
                TurtleApi.put(side, block)
            end
        end
    end
end
