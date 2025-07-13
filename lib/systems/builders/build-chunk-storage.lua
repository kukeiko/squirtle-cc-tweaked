local TurtleApi = require "lib.apis.turtle.turtle-api"
local ItemApi = require "lib.apis.item-api"

---Creates a compact storage system with a modem block for a turtle to connect to it.
---Starting position is expected to be where a turtle would dock to the storage: directly in front of the modem block.
---@param chestLayers? integer How many layers of chests should be built - defaults to 9. Total number of chest blocks = numChestLayers * 4
return function(chestLayers)
    chestLayers = chestLayers or 9

    local up = TurtleApi.up
    local down = TurtleApi.down
    local left = TurtleApi.left
    local right = TurtleApi.right
    local forward = TurtleApi.forward
    local back = TurtleApi.back
    local ahead = TurtleApi.ahead
    local below = TurtleApi.below
    local above = TurtleApi.above
    local strafe = TurtleApi.strafe

    -- computer with dock
    forward(2)
    above(ItemApi.computer)
    forward()
    above(ItemApi.wiredModem)
    -- select an item we definitely have in order to right click
    TurtleApi.selectItem(ItemApi.diskDrive)
    TurtleApi.place("up")
    back()
    ahead(ItemApi.networkCable)
    back()
    ahead(ItemApi.networkCable)
    up()
    below(ItemApi.wiredModem)

    -- barrel #1
    strafe("left")
    below(ItemApi.smoothStone)
    back()
    below(ItemApi.smoothStone)
    forward(2)
    below(ItemApi.smoothStone)
    forward()
    ahead(ItemApi.smoothStone)
    back()
    ahead(ItemApi.barrel)

    -- left border
    strafe("left")

    for i = 1, 4 do
        ahead(ItemApi.smoothStone)

        if i ~= 4 then
            back()
        end
    end

    -- back border
    left()

    for _ = 1, 4 do
        back()
        ahead(ItemApi.smoothStone)
    end

    -- right border
    left()

    for _ = 1, 3 do
        back()
        ahead(ItemApi.smoothStone)
    end

    right()
    right()
    ahead(ItemApi.smoothStone)
    up()
    below(ItemApi.smoothStone)

    -- chest column #1
    for i = 1, chestLayers do
        ahead(ItemApi.chest)

        if i ~= chestLayers then
            up()
        end
    end

    -- modems
    left()
    forward(2)
    right()

    for i = 1, chestLayers do
        ahead(ItemApi.wiredModem)

        if i ~= chestLayers then
            down()
        end
    end

    -- remaining platform
    back(2)
    strafe("right")
    down()
    below(ItemApi.smoothStone)
    forward()
    below(ItemApi.smoothStone)
    forward()
    below(ItemApi.smoothStone)
    forward()
    ahead(ItemApi.smoothStone)
    back()
    ahead(ItemApi.barrel)
    up()

    -- chest column #2
    for i = 1, chestLayers do
        ahead(ItemApi.chest)

        if i ~= chestLayers then
            up()
        end
    end

    -- chest column #3
    up()
    forward(2)
    left()
    forward(2)
    left()
    down()

    for _ = 1, chestLayers - 1 do
        ahead(ItemApi.chest)
        down()
    end

    forward(2)
    right()
    right()
    ahead(ItemApi.chest)

    -- chest column #4
    strafe("left")

    for i = 1, chestLayers do
        ahead(ItemApi.chest)

        if i ~= chestLayers then
            up()
        end
    end

    -- turn on modems
    right()
    forward(2)
    left()

    -- select an item we definitely have in order to right click
    TurtleApi.selectItem(ItemApi.diskDrive)

    for i = 1, chestLayers do
        TurtleApi.place()

        if i ~= chestLayers then
            down()
        end
    end

    -- go back to start
    back(2)
    down(2)
end
