local Rpc = require "lib.tools.rpc"
local ApplicationService = require "lib.system.application-service"
local TurtleApi = require "lib.turtle.turtle-api"
local ItemApi = require "lib.inventory.item-api"
local InventoryApi = require "lib.inventory.inventory-api"

---Creates a compact storage system with a modem block for a turtle to connect to it.
---Starting position is expected to be where a turtle would dock to the storage: directly in front of the modem block.
---@param storageLabel string The label to set for the storage computer
---@param chestLayers? integer How many layers of chests should be built - defaults to 9. Total number of chest blocks = numChestLayers * 4
return function(storageLabel, chestLayers)
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
    TurtleApi.use("up", ItemApi.diskDrive)
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

    -- chest column #1 (right-outer)
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

    -- chest column #2 (right-inner)
    for i = 1, chestLayers do
        ahead(ItemApi.chest)

        if i == 1 then
            -- storage power chest
            below(ItemApi.chest)

            for _, powerItem in pairs(InventoryApi.getPowerItems(6)) do
                if TurtleApi.isSimulating() then
                    TurtleApi.recordPlacedBlock(powerItem.item, 1)
                else
                    TurtleApi.selectItem(powerItem.item)
                    TurtleApi.drop("bottom", 1)
                end
            end
        end

        if i ~= chestLayers then
            up()
        end
    end

    -- chest column #3 (left-inner)
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

    -- chest column #4 (left-outer)
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

    for i = 1, chestLayers do
        -- select an item we definitely have in order to right click
        TurtleApi.use("forward", ItemApi.diskDrive)

        if i ~= chestLayers then
            down()
        end
    end

    -- install storage app
    back(1)
    ahead(ItemApi.diskDrive)
    TurtleApi.selectItem(ItemApi.disk)
    TurtleApi.drop("front")

    if TurtleApi.isSimulating() then
        TurtleApi.recordPlacedBlock(ItemApi.disk)
    else
        local appService = Rpc.nearest(ApplicationService)
        local storageApp = appService.getApplication("computer", "storage", true)
        local storageFile = fs.open("disk/storage", "w")
        storageFile.write(storageApp.content)
        storageFile.close()

        local storageStartupFile = fs.open("disk/storage-startup", "w")
        storageStartupFile.write("shell.run(\"storage right auto-storage\")\n")
        storageStartupFile.close()

        local startupFile = fs.open("disk/startup", "w")
        startupFile.write("shell.run(\"copy disk/storage storage\")\n")
        startupFile.write("shell.run(\"copy disk/storage-startup startup\")\n")
        startupFile.write(string.format("shell.run(\"label set \\\"%s\\\"\")\n", storageLabel))
        startupFile.close()
    end

    down()

    if not TurtleApi.isSimulating() then
        local computerIsOn = peripheral.call("front", "isOn")
        peripheral.call("front", computerIsOn and "reboot" or "turnOn")
    end

    up()
    TurtleApi.suck()
    TurtleApi.dig()
    up()
    forward()
    below(ItemApi.wirelessModem)
    back()
    down(2)

    if not TurtleApi.isSimulating() then
        peripheral.call("front", "reboot")
    end

    -- go back to start
    back()
    down()
end
