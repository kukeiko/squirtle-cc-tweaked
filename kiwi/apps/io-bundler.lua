-- app for a turtle that has a home base with an io-chest attached to put output in
-- and take input out. it will then follow a path and look for other io-chests (e.g. a farm of a lumberjack)
-- and put input in and take output out.
package.path = package.path .. ";/?.lua"

local KiwiUtils = require "kiwi.utils"
local KiwiPeripheral = require "kiwi.core.peripheral"
local KiwiChest = require "kiwi.core.chest"
local KiwiSide = require "kiwi.core.side"
local KiwiInventory = require "kiwi.turtle.inventory"
local inspect = require "kiwi.turtle.inspect"
local move = require "kiwi.turtle.move"
local turn = require "kiwi.turtle.turn"
local takeInputAndPushOutput = require "kiwi.inventory.take-input-and-push-output"
local suckSlotFromChest = require "kiwi.inventory.suck-slot-from-chest"
local pushInput = require "kiwi.inventory.push-input"
local takeOutput = require "kiwi.inventory.take-output"

---@class IoBundlerAppState
---@field maxStock table<string, integer>
---@field inputStacks KiwiDetailedItemStack[]
---@field outputStacks KiwiDetailedItemStack[]

---@param chest KiwiChest
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

---@param chest KiwiChest
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

---@param chest KiwiChest
---@return table<string, integer>
local function getMaxStock(chest)
    local items = chest:getDetailedItemList()

    ---@type table<string, integer>
    local maxStock = {}
    local inputStacks = getInputStacks(chest)

    for _, item in pairs(inputStacks) do
        maxStock[item.name] = (maxStock[item.name] or 0) + item.maxCount
    end

    for slot = chest:getFirstOutputSlot(), chest:getLastOutputSlot() do
        local item = items[slot]

        if item ~= nil then
            local numMissing = item:numMissing()

            if numMissing > 0 then
                maxStock[item.name] = (maxStock[item.name] or 0) + numMissing
            end
        end
    end

    return maxStock
end

local function dumpInventoryToBarrel()
    -- [todo] list() might return an array with all slots set in the future
    for slot in pairs(KiwiInventory.list()) do
        KiwiInventory.selectSlot(slot)
        -- [todo] hardcoded side & using native directly
        turtle.dropDown()
    end
end

---@param stacks KiwiDetailedItemStack[]
---@param barrel KiwiChest
local function suckStacksFromBarrel(stacks, barrel)
    for _, item in pairs(stacks) do
        for barrelSlot, barrelItem in pairs(barrel:getItemList()) do
            if barrelItem.name == item.name then
                -- [todo] assuming that the slot has enough. as a hack, we could first condense the barrel.
                suckSlotFromChest(barrel.side, barrelSlot)
                break
            end
        end
    end
end

---@param buffer KiwiChest
---@param ioChest KiwiChest
local function doHomework(buffer, ioChest)
    dumpInventoryToBarrel()
    takeInputAndPushOutput(buffer, ioChest)
end

---@param maxStock table<string, integer>
---@param inputStacks KiwiDetailedItemStack[]
---@param outputStacks KiwiDetailedItemStack[]
local function doRemoteWork(maxStock, inputStacks, outputStacks)
    print("doin remote work")
    local ioChest = KiwiChest.new(KiwiPeripheral.findSide("minecraft:chest"))
    print("dumping inventory to barrel")
    dumpInventoryToBarrel()
    local bufferBarrel = KiwiChest.new(KiwiSide.bottom)
    print("pushing input to io-chest")
    pushInput(bufferBarrel, ioChest)
    print("take output from io-chest")
    takeOutput(ioChest, bufferBarrel, maxStock)
    print("sucking input from barrel")
    suckStacksFromBarrel(inputStacks, bufferBarrel)
    print("sucking output from barrel")
    suckStacksFromBarrel(outputStacks, bufferBarrel)
end

---@param barrel KiwiChest
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
    -- local bufferBarrel = KiwiChest.new(KiwiPeripheral.findSide("minecraft:barrel"))
    -- local ioChest = KiwiChest.new(KiwiPeripheral.findSide("minecraft:chest"))
    -- local inputStacks -- = getInputStacks(ioChest)
    -- local outputStacks -- = getOutputStacks(ioChest)
    -- local maxStock

    -- [todo] i expected loadAppState() to write if not exists. consider doing that?
    if not KiwiUtils.hasAppState("io-bundler") then
        KiwiUtils.saveAppState(getDefaultState(), "io-bundler")
    end

    -- [todo] state.inputStacks & outputStacks arent really KiwiDetailedItemStack[],
    -- for now its all good as we only read data and dont call any class instance methods. yet.
    ---@type IoBundlerAppState
    local state = KiwiUtils.loadAppState("io-bundler", getDefaultState())

    -- if state ~= nil then
    --     inputStacks = state.inputStacks
    --     outputStacks = state.outputStacks
    --     maxStock = state.maxStock
    -- end
    -- doHomework(bufferBarrel, ioChest)
    -- local maxStock = getMaxStock(ioChest)
    -- suckStacksFromBarrel(inputStacks, bufferBarrel)
    -- now it time go farm collect, yes?

    while true do
        local bottom = inspect(KiwiSide.bottom)

        if bottom and bottom.name == "minecraft:barrel" then
            print("bottom is barrel? but is it home?")
            local bufferBarrel = KiwiChest.new(KiwiPeripheral.findSide("minecraft:barrel"))

            if isHomeBarrel(bufferBarrel) then
                print("yes, it be home! doin homework")
                local ioChest = KiwiChest.new(KiwiPeripheral.findSide("minecraft:chest"))
                state.inputStacks = getInputStacks(ioChest)
                state.outputStacks = getOutputStacks(ioChest)
                -- doHomework(bufferBarrel, ioChest)
                print("dump inventory to barrel")
                dumpInventoryToBarrel()
                print("take input and push output")
                takeInputAndPushOutput(bufferBarrel, ioChest)
                state.maxStock = getMaxStock(ioChest)
                print("sucking input from barrel")
                suckStacksFromBarrel(state.inputStacks, bufferBarrel)
                print("saving state to disk")
                -- [todo] saving doesnt work yet? i guess it has to do with disk size.
                -- but interestingly enough {foo = 1} can be saved.
                -- KiwiUtils.saveAppState(state.maxStock, "io-bundler")
                KiwiUtils.saveAppState(state, "io-bundler")
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
            turn(KiwiSide.right)
        end
    end
end

return main(arg)
