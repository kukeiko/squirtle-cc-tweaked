---@generic T
---@param a T
---@param b T
---@return T, T
local function swap(a, b)
    return b, a
end

-- [todo] ❌ using dig() for up/down, but move() for digging forward, and move() probes blocks, while dig() doesn't.
-- I think I should just also use dig() for forward digging, as the probing from move() costs quite a lot of time.
---@param TurtleApi TurtleApi
---@param depth integer
---@param width integer
---@param height integer
---@param homePosition? Vector
---@param homeFacing? integer
return function(TurtleApi, depth, width, height, homePosition, homeFacing)
    assert(depth > 0, "depth must be greater than 0")
    assert(width ~= 0, "width can't be 0")
    assert(height ~= 0, "height can't be 0")
    local vertical = "up"

    if height < 0 then
        vertical = "down"
    end

    height = math.abs(height)

    if depth < 3 and math.abs(width) == 1 then
        for y = 1, height do
            if depth == 2 then
                TurtleApi.dig()
            end

            if y ~= height then
                TurtleApi.move(vertical)
            end
        end

        if vertical == "down" then
            TurtleApi.move("up", height - 1)
        else
            TurtleApi.move("down", height - 1)
        end

        return
    end

    homePosition = homePosition or TurtleApi.getPosition()
    homeFacing = homeFacing or TurtleApi.getFacing()

    if math.abs(width) > depth then
        if width > 0 then
            TurtleApi.turn("right")
            depth = -depth
        else
            TurtleApi.turn("left")
            width = -width
        end

        width, depth = swap(width, depth)
    end

    local left = "left"
    local right = "right"

    if width < 0 then
        left = "right"
        right = "left"
        width = math.abs(width)
    end

    ---@param y integer
    local function digColumn(y)
        for row = 1, depth do
            if y ~= 1 then
                TurtleApi.dig(vertical == "up" and "down" or "up")
            end

            if y ~= height then
                TurtleApi.dig(vertical == "up" and "up" or "down")
            end

            if not TurtleApi.isSimulating() and TurtleApi.isFull() then
                TurtleApi.tryLoadShulkers()
            end

            if row ~= depth then
                TurtleApi.move()
            end
        end
    end

    ---@param column integer
    ---@param layer integer
    local function moveToNextColumn(column, layer)
        local direction = left

        if width % 2 == 0 and layer % 2 == 0 then
            if column % 2 == 0 then
                direction = right
            end
        elseif column % 2 == 1 then
            direction = right
        end

        TurtleApi.turn(direction)
        TurtleApi.move()
        TurtleApi.turn(direction)
    end

    local layers = math.ceil(height / 3)
    local remainder = height % 3
    local y = 1

    if height > 2 then
        TurtleApi.move(vertical)
        y = 2
    end

    for layer = 1, layers do
        for column = 1, width do
            digColumn(y)

            if column == width then
                if layer ~= layers then
                    TurtleApi.turn("back")
                end
            else
                moveToNextColumn(column, layer)
            end
        end

        if layer < layers then
            if layer + 1 == layers and remainder ~= 0 then
                TurtleApi.move(vertical, remainder)
                y = y + remainder
            else
                TurtleApi.move(vertical, 3)
                y = y + 3
            end
        end
    end

    if not TurtleApi.isSimulating() then
        TurtleApi.tryLoadShulkers()
    end

    TurtleApi.moveToPoint(homePosition)
    TurtleApi.face(homeFacing)
end
