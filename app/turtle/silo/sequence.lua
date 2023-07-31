---@param squirtle SimulatableSquirtle
---@param state SiloAppState
return function(squirtle, state)
    if state.lampLocation == "right" then
        squirtle:right()
        squirtle:move("forward", 2)
        squirtle:left()
    elseif state.lampLocation == "left" then
        squirtle:right()
        squirtle:move("forward", 4)
        squirtle:left()
        squirtle:flipTurns(true)
    end

    -- place center chests
    for _ = 1, (state.layers * 2) + 1 do
        squirtle:place(state.blocks.chest)
        squirtle:up()
    end

    -- place left support beam
    squirtle:forward()
    squirtle:right()
    squirtle:back(2)
    squirtle:place(state.blocks.support, "top")
    squirtle:down()
    squirtle:place(state.blocks.support, "top")

    -- place left hoppers
    for _ = 1, state.layers do
        squirtle:down()
        squirtle:place(state.blocks.support, "top")
        squirtle:place(state.blocks.hopper)
        squirtle:down()
        squirtle:place(state.blocks.support, "top")
    end

    -- place bottom support beam
    squirtle:dig("down")
    squirtle:down()
    squirtle:place(state.blocks.support, "top")
    squirtle:right()
    squirtle:dig()
    squirtle:forward()
    squirtle:up()

    -- right support
    squirtle:left()
    squirtle:forward(4)
    squirtle:left()
    squirtle:forward()
    squirtle:left()

    for _ = 1, state.layers do
        squirtle:place(state.blocks.hopper)
        squirtle:up()
        squirtle:place(state.blocks.support, "down")
        squirtle:up()
        squirtle:place(state.blocks.support, "down")
    end

    for _ = 1, 2 do
        squirtle:up()
        squirtle:place(state.blocks.support, "down")
    end

    -- build top support
    squirtle:forward(2)

    for i = 1, 5 do
        squirtle:place(state.blocks.support)

        if i ~= 5 then
            squirtle:back()
        end
    end

    -- build right support incl. lights
    for _ = 1, (state.layers * 2) + 2 do
        squirtle:down()
        squirtle:place(state.blocks.support, "top")
        squirtle:place(state.blocks.lamp)
    end

    -- bottom piece of right support
    squirtle:dig("down")
    squirtle:down()
    squirtle:place(state.blocks.support, "top")
    squirtle:left()
    squirtle:dig()
    squirtle:forward()
    squirtle:up()

    -- place remaining chests
    squirtle:right()
    squirtle:forward(3)
    squirtle:right()

    for _ = 1, state.layers do
        squirtle:up()
        squirtle:place(state.blocks.chest)
        squirtle:up()
    end

    squirtle:left()
    squirtle:forward(2)
    squirtle:right()

    for i = 1, state.layers + 1 do
        squirtle:place(state.blocks.chest)

        if i ~= 5 then
            squirtle:down(2)
        end
    end

    -- move to backside
    squirtle:left()
    squirtle:forward()
    squirtle:down()
    squirtle:right()
    squirtle:forward()
    squirtle:dig()
    squirtle:forward()
    squirtle:up()
    squirtle:left()
    squirtle:back(2)

    local function placeBacksideBlocks()
        squirtle:place(state.blocks.filler, "down")
        squirtle:right()
        squirtle:forward()
        squirtle:place(state.blocks.filler, "down")
        squirtle:back()
        squirtle:left()

        for _ = 1, 3 do
            squirtle:forward()
            squirtle:place(state.blocks.backside, "down")
        end

        squirtle:back()
    end

    -- place outer redstone circuit from chest to lamps
    ---@param isBottomLayer boolean
    local function placeOuterRedstone(isBottomLayer)
        local function placeBottomLayerBlock()
            squirtle:down()
            squirtle:dig("down")
            squirtle:place(state.blocks.filler, "down")
            squirtle:up()
        end

        squirtle:right()
        squirtle:forward()
        squirtle:dig("down")
        squirtle:place(state.blocks.filler, "down")
        squirtle:up()
        squirtle:place(state.blocks.comparator, "down")
        squirtle:forward()
        squirtle:place(state.blocks.filler, "down")
        squirtle:right()
        squirtle:forward()

        if isBottomLayer then
            placeBottomLayerBlock()
        end

        squirtle:place(state.blocks.repeater, "down")
        squirtle:forward()
        squirtle:place(state.blocks.filler, "down")
        squirtle:forward()

        if isBottomLayer then
            placeBottomLayerBlock()
        end

        squirtle:place(state.blocks.repeater, "down")
        squirtle:forward()
        squirtle:place(state.blocks.filler, "down")
        squirtle:right()

        for _ = 1, 2 do
            squirtle:forward()
            squirtle:down()

            if isBottomLayer then
                squirtle:dig("down")
            end

            squirtle:place(state.blocks.filler, "down")
            squirtle:up()
            squirtle:place(state.blocks.redstone, "down")
        end

        squirtle:right()
        squirtle:forward(2)
        placeBacksideBlocks()
    end

    -- place inner redstone circuit from chest to lamps
    local function placeInnerRedstone()
        squirtle:back()
        squirtle:right()
        squirtle:forward()
        squirtle:place(state.blocks.filler, "down")
        squirtle:up()
        squirtle:place(state.blocks.comparator, "down")
        squirtle:forward()
        squirtle:place(state.blocks.filler, "down")
        squirtle:right()
        squirtle:forward()
        squirtle:place(state.blocks.repeater, "down")
        squirtle:forward()
        squirtle:place(state.blocks.filler, "down")
        squirtle:right()
        squirtle:forward()
        squirtle:down()
        squirtle:place(state.blocks.filler, "down")
        squirtle:up()
        squirtle:place(state.blocks.repeater, "down")
        squirtle:forward()
        squirtle:down()
        squirtle:place(state.blocks.filler, "down")
        squirtle:up()
        squirtle:place(state.blocks.filler, "down")
        squirtle:right()
        squirtle:forward()
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
    squirtle:forward()
    squirtle:left()
    squirtle:back()
    squirtle:down()
    squirtle:dig()
    squirtle:place(state.blocks.hopper)
    squirtle:right()
    squirtle:forward(2)
    squirtle:left()
    squirtle:forward()
    squirtle:left()
    squirtle:place(state.blocks.hopper)

    -- redstone torch
    squirtle:down()
    squirtle:forward()
    squirtle:left()
    squirtle:place(state.blocks.filler)
    squirtle:down()
    squirtle:place(state.blocks.redstoneTorch, "up")

    -- "plus" construct
    squirtle:forward(2)
    squirtle:up()
    squirtle:place(state.blocks.filler, "down")
    squirtle:around()
    squirtle:up()
    squirtle:place(state.blocks.repeater, "down")
    squirtle:back()
    squirtle:place(state.blocks.filler, "down")
    squirtle:up()
    squirtle:place(state.blocks.redstone, "down")

    for _ = 1, 2 do
        squirtle:forward()
        squirtle:place(state.blocks.filler, "down")
    end

    squirtle:around()
    squirtle:up()

    -- input chest connection to topmost redstone lamp
    squirtle:place(state.blocks.comparator, "down")
    squirtle:forward()
    squirtle:place(state.blocks.redstone, "down")
    squirtle:right()
    squirtle:forward()
    squirtle:down()
    squirtle:place(state.blocks.filler, "down")
    squirtle:up()
    squirtle:place(state.blocks.redstone, "down")
    squirtle:forward()
    squirtle:place(state.blocks.repeater, "down")
    squirtle:forward()
    squirtle:place(state.blocks.filler, "down")
    squirtle:forward()
    squirtle:place(state.blocks.repeater, "down")
    squirtle:forward()
    squirtle:place(state.blocks.filler, "down")
    squirtle:right()
    squirtle:forward()
    squirtle:down()
    squirtle:place(state.blocks.filler, "down")
    squirtle:up()
    squirtle:place(state.blocks.repeater, "down")
    squirtle:forward()
    squirtle:down()
    squirtle:place(state.blocks.filler, "down")
    squirtle:up()
    squirtle:place(state.blocks.filler, "down")

    -- last row of chest backing blocks + input chest
    squirtle:right()
    squirtle:forward()
    placeBacksideBlocks()
    squirtle:forward(2)
    squirtle:left()
    squirtle:place(state.blocks.chest, "down")

    -- go back home while placing last column of filler blocks
    squirtle:back()
    squirtle:left()
    squirtle:forward()
    squirtle:down()

    for _ = 1, (state.layers * 2) + 1 do
        squirtle:down()
        squirtle:place(state.blocks.filler, "top")
    end

    squirtle:back()
    squirtle:place(state.blocks.filler)
    squirtle:right()
    squirtle:forward()
    squirtle:down()
    squirtle:forward(2)
    squirtle:up()

    -- done!
    if state.lampLocation == "right" then
        squirtle:around()
    else
        squirtle:flipTurns(false)
        squirtle:right()
        squirtle:move("forward", 6)
        squirtle:right()
    end
end
