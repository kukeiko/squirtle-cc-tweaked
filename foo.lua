package.path = package.path .. ";/lib/?.lua"

local Utils = require "utils"
local Side = require "elements.side"
local Chest = require "world.chest"
local pullInput = require "squirtle.transfer.pull-input"
local pushOutput = require "squirtle.transfer.push-output"
local inspect = require "squirtle.inspect"
local Backpack = require "squirtle.backpack"

-- local Furnaces = require "world.furnaces"
-- local value = Furnaces.getFuelStack(Side.right)
-- print(Furnaces.getFuelStack(Side.right))

local function drainDropper()
    local itemCount = Chest.countItems(Side.bottom)
    local side = Side.getName(Side.bottom)
    redstone.setOutput(side, true)
    os.sleep(.25)
    redstone.setOutput(side, false)

    while Chest.countItems(Side.bottom) ~= itemCount do
        print("dropper changed chest! sending redstone pulse again...")
        itemCount = Chest.countItems(Side.bottom)
        redstone.setOutput(side, true)
        os.sleep(.25)
        redstone.setOutput(side, false)
    end

    print("dropper emptied out or chest full")
end

-- drainDropper()

local function backpackGetItemStockAutocompleteTest()
    print(Backpack.getItemStock("minecraft:birch_sapling"))

    -- making sure we have autocomplete on stack argument
    print(Backpack.getItemStock(function(stack)
        return stack.name == "minecraft:birch_sapling"
    end))
end

backpackGetItemStockAutocompleteTest()
