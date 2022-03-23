-- app for a turtle that has a home base with an io-chest attached to put output in
-- and take input out. it will then follow a path and look for other io-chests (e.g. a farm of a lumberjack)
-- and put input in and take output out.
package.path = package.path .. ";/lib/?.lua"

local Utils = require "utils"
local Peripheral = require "world.peripheral"
local Chest = require "world.chest"
local Side = require "elements.side"
local inspect = require "squirtle.inspect"
local move = require "squirtle.move"
local turn = require "squirtle.turn"
local suckSlotFromChest = require "squirtle.transfer.suck-slot-from-chest"
local takeOutput = require "squirtle.transfer.take-output"
local pushInput = require "squirtle.transfer.push-input"
local pullInput = require "squirtle.transfer.pull-input"
local pushOutput = require "squirtle.transfer.push-output"
local dump = require "squirtle.dump"

---@class IoBundlerAppState
---@field maxStock table<string, integer>
---@field inputStacks DetailedItemStack[]
---@field outputStacks DetailedItemStack[]

---@param chest Chest
local function getInputStacks(chest)
    local items = chest:getDetailedItemList()
    local inputStacks = {}

    for slot = chest:getFirstInputSlot(), chest:getLastInputSlot() do
        local item = items[slot]

        if item ~= nil then
            inputStacks[slot] = item
        end
    end

    return inputStacks
end

---@param chest Chest
local function getOutputStacks(chest)
    local items = chest:getDetailedItemList()
    local outputStacks = {}

    for slot = chest:getFirstOutputSlot(), chest:getLastOutputSlot() do
        local item = items[slot]

        if item ~= nil then
            outputStacks[slot] = item
        end
    end

    return outputStacks
end

---@param side integer
---@return table<string, integer>
local function getMaxStock(side)
    local maxStock = Chest.getInputMaxStock(side)

    for item, count in pairs(Chest.getOutputMissingStock(side)) do
        maxStock[item] = (maxStock[item] or 0) + count
    end

    return maxStock
end

---@param stacks DetailedItemStack[]
---@param barrel Chest
local function suckStacksFromBarrel(stacks, barrel)
    -- [todo] quite dirtily & unefficient method; doesn't stop on first suck fail
    for _, item in pairs(stacks) do
        for barrelSlot, barrelItem in pairs(barrel:getItemList()) do
            if barrelItem.name == item.name then
                -- [todo] we're assuming that the slot has enough. as a hack, we could first condense the barrel.
                suckSlotFromChest(barrel.side, barrelSlot)
                break
            end
        end
    end
end

---@param maxStock table<string, integer>
---@param inputStacks DetailedItemStack[]
---@param outputStacks DetailedItemStack[]
local function doRemoteWork(maxStock, inputStacks, outputStacks)
    print("doin remote work")
    local ioChest = Chest.new(Peripheral.findSide("minecraft:chest"))
    print("dumping inventory to barrel")
    dump(Side.bottom)
    local bufferBarrel = Chest.new(Side.bottom)
    print("pushing input to io-chest")
    pushInput(bufferBarrel, ioChest)
    print("take output from io-chest")
    takeOutput(ioChest, bufferBarrel, maxStock)
    print("sucking input from barrel")
    suckStacksFromBarrel(inputStacks, bufferBarrel)
    print("sucking output from barrel")
    suckStacksFromBarrel(outputStacks, bufferBarrel)
end

---@param barrel Chest
local function isHomeBarrel(barrel)
    local items = barrel:getDetailedItemList()

    for _, item in pairs(items) do
        if item.name == "minecraft:name_tag" and item.displayName == "Home" then
            return true
        end
    end

    return false
end

local function getDefaultState()
    ---@type IoBundlerAppState
    local state = {inputStacks = {}, outputStacks = {}, maxStock = {}}

    return state
end

local function main(args)
    -- [todo] i expected loadAppState() to write if not exists. consider doing that?
    if not Utils.hasAppState("io-bundler") then
        Utils.saveAppState(getDefaultState(), "io-bundler")
    end

    -- [todo] state.inputStacks & outputStacks arent really DetailedItemStack[],
    -- for now its all good as we only read data and dont call any class instance methods. yet.
    ---@type IoBundlerAppState
    local state = Utils.loadAppState("io-bundler", getDefaultState())

    while true do
        local bottom = inspect(Side.bottom)

        if bottom and bottom.name == "minecraft:barrel" then
            print("bottom is barrel? but is it home?")
            local bufferBarrel = Chest.new(Peripheral.findSide("minecraft:barrel"))

            if isHomeBarrel(bufferBarrel) then
                print("yes, it be home! doin homework")
                local ioChest = Chest.new(Peripheral.findSide("minecraft:chest"))
                state.inputStacks = getInputStacks(ioChest)
                state.outputStacks = getOutputStacks(ioChest)
                -- doHomework(bufferBarrel, ioChest)
                print("dump inventory to barrel")
                dump(Side.bottom)

                print("pulling input")
                pullInput(ioChest.side, bufferBarrel.side)

                print("pushing output")
                local inputMaxStock = Chest.getInputMaxStock(ioChest.side)
                pushOutput(bufferBarrel.side, ioChest.side, inputMaxStock)

                print("determining stock for next round")
                local outputMissingStock = Chest.getOutputMissingStock(ioChest.side)
                state.maxStock = Chest.addStock(inputMaxStock, outputMissingStock)

                print("sucking input from barrel")
                suckStacksFromBarrel(state.inputStacks, bufferBarrel)

                print("saving state to disk")
                -- [todo] saving doesnt work yet? i guess it has to do with disk size.
                -- but interestingly enough {foo = 1} can be saved.
                Utils.saveAppState(state, "io-bundler")
            else
                doRemoteWork(state.maxStock, state.inputStacks, state.outputStacks)
            end
        end

        while not move() do
            local block = inspect()

            if not block then
                error("could not move even though there is nothing in front of me")
            end

            print("obstacle, turning right")
            turn(Side.right)
        end
    end
end

return main(arg)
