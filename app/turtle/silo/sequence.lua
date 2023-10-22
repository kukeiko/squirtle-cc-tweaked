local SquirtleV2 = require "squirtle.squirtle-v2"

---@param state SiloAppState
return function(state)
    local move = SquirtleV2.move
    local forward = SquirtleV2.forward
    local up = SquirtleV2.up
    local down = SquirtleV2.down
    local back = SquirtleV2.back
    local right = SquirtleV2.right
    local left = SquirtleV2.left
    local placeFront = SquirtleV2.placeFront
    local placeUp = SquirtleV2.placeUp
    local placeDown = SquirtleV2.placeDown
    local around = SquirtleV2.around

    local restoreBreakable = SquirtleV2.setBreakable(function()
        return true
    end)

    if state.lampLocation == "right" then
        right()
        forward(2)
        left()
    elseif state.lampLocation == "left" then
        right()
        forward(4)
        left()
        SquirtleV2.flipTurns = true
    end

    -- place center chests
    for _ = 1, (state.layers * 2) + 1 do
        placeFront(state.blocks.chest)
        up()
    end

    -- place left support beam
    forward()
    right()
    back(2)
    placeUp(state.blocks.support)
    down()
    placeUp(state.blocks.support)

    -- place left hoppers
    for _ = 1, state.layers do
        down()
        placeUp(state.blocks.support)
        placeFront(state.blocks.hopper)
        down()
        placeUp(state.blocks.support)
    end

    -- place bottom support beam
    down()
    placeUp(state.blocks.support)
    right()
    forward()
    up()

    -- right support
    left()
    forward(4)
    left()
    forward()
    left()

    for _ = 1, state.layers do
        placeFront(state.blocks.hopper)
        up()
        placeDown(state.blocks.support)
        up()
        placeDown(state.blocks.support)
    end

    for _ = 1, 2 do
        up()
        placeDown(state.blocks.support)
    end

    -- build top support
    forward(2)

    for i = 1, 5 do
        placeFront(state.blocks.support)

        if i ~= 5 then
            back()
        end
    end

    -- build right support incl. lights
    for _ = 1, (state.layers * 2) + 2 do
        down()
        placeUp(state.blocks.support)
        placeFront(state.blocks.lamp)
    end

    -- bottom piece of right support
    down()
    placeUp(state.blocks.support)
    left()
    forward()
    up()

    -- place remaining chests
    right()
    forward(3)
    right()

    for _ = 1, state.layers do
        up()
        placeFront(state.blocks.chest)
        up()
    end

    left()
    forward(2)
    right()

    for i = 1, state.layers + 1 do
        placeFront(state.blocks.chest)

        if i ~= state.layers + 1 then
            down(2)
        end
    end

    -- move to backside
    left()
    forward()
    down()
    right()
    forward()
    forward()
    up()
    left()
    back(2)

    local function placeBacksideBlocks()
        placeDown(state.blocks.filler)
        right()
        forward()
        placeDown(state.blocks.filler)
        back()
        left()

        for _ = 1, 3 do
            forward()
            placeDown(state.blocks.backside)
        end

        back()
    end

    -- place outer redstone circuit from chest to lamps
    ---@param isBottomLayer boolean
    local function placeOuterRedstone(isBottomLayer)
        local function placeBottomLayerBlock()
            down()
            placeDown(state.blocks.filler)
            up()
        end

        right()
        forward()
        placeDown(state.blocks.filler)
        up()
        placeDown(state.blocks.comparator)
        forward()
        placeDown(state.blocks.filler)
        right()
        forward()

        if isBottomLayer then
            placeBottomLayerBlock()
        end

        placeDown(state.blocks.repeater)
        forward()
        placeDown(state.blocks.filler)
        forward()

        if isBottomLayer then
            placeBottomLayerBlock()
        end

        placeDown(state.blocks.repeater)
        forward()
        placeDown(state.blocks.filler)
        right()

        for _ = 1, 2 do
            forward()
            down()
            placeDown(state.blocks.filler)
            up()
            placeDown(state.blocks.redstone)
        end

        right()
        forward(2)
        placeBacksideBlocks()
    end

    -- place inner redstone circuit from chest to lamps
    local function placeInnerRedstone()
        back()
        right()
        forward()
        placeDown(state.blocks.filler)
        up()
        placeDown(state.blocks.comparator)
        forward()
        placeDown(state.blocks.filler)
        right()
        forward()
        placeDown(state.blocks.repeater)
        forward()
        placeDown(state.blocks.filler)
        right()
        forward()
        down()
        placeDown(state.blocks.filler)
        up()
        placeDown(state.blocks.repeater)
        forward()
        down()
        placeDown(state.blocks.filler)
        up()
        placeDown(state.blocks.filler)
        right()
        forward()
        placeBacksideBlocks()
    end

    for i = 1, (state.layers * 2) + 1 do
        if i % 2 == 1 then
            placeOuterRedstone(i == 1)
        else
            placeInnerRedstone()
        end
    end

    -- build input chest
    forward()
    left()
    back()
    down()
    placeFront(state.blocks.hopper)
    right()
    forward(2)
    left()
    forward()
    left()
    placeFront(state.blocks.hopper)

    -- redstone torch
    down()
    forward()
    left()
    placeFront(state.blocks.filler)
    down()
    placeUp(state.blocks.redstoneTorch)

    -- "plus" construct
    forward(2)
    up()
    placeDown(state.blocks.filler)
    around()
    up()
    placeDown(state.blocks.repeater)
    back()
    placeDown(state.blocks.filler)
    up()
    placeDown(state.blocks.redstone)

    for _ = 1, 2 do
        forward()
        placeDown(state.blocks.filler)
    end

    around()
    up()

    -- input chest connection to topmost redstone lamp
    placeDown(state.blocks.comparator)
    forward()
    placeDown(state.blocks.redstone)
    right()
    forward()
    down()
    placeDown(state.blocks.filler)
    up()
    placeDown(state.blocks.redstone)
    forward()
    placeDown(state.blocks.repeater)
    forward()
    placeDown(state.blocks.filler)
    forward()
    placeDown(state.blocks.repeater)
    forward()
    placeDown(state.blocks.filler)
    right()
    forward()
    down()
    placeDown(state.blocks.filler)
    up()
    placeDown(state.blocks.repeater)
    forward()
    down()
    placeDown(state.blocks.filler)
    up()
    placeDown(state.blocks.filler)

    -- last row of chest backing blocks + input chest
    right()
    forward()
    placeBacksideBlocks()
    forward(2)
    left()
    placeDown(state.blocks.chest)

    -- go back home while placing last column of filler blocks
    back()
    left()
    forward()
    down()

    for _ = 1, (state.layers * 2) + 1 do
        down()
        placeUp(state.blocks.filler)
    end

    back()
    placeFront(state.blocks.filler)
    right()
    forward()
    down()
    forward(2)
    up()

    -- done!
    if state.lampLocation == "right" then
        around()
    else
        SquirtleV2.flipTurns = false
        right()
        move("forward", 6)
        right()
    end

    restoreBreakable()
end
