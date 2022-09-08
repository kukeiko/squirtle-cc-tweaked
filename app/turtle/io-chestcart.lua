package.path = package.path .. ";/lib/?.lua"

local findPeripheralSide = require "world.peripheral.find-side"
local Redstone = require "world.redstone"
local Backpack = require "squirtle.backpack"
local turn = require "squirtle.turn"
local inspect = require "squirtle.inspect"
local suck = require "squirtle.suck"
local dump = require "squirtle.dump"
local place = require "squirtle.place"
local dig = require "squirtle.dig"
local count = require "utils.count"
local toInventory = require "inventory.to-inventory"
local toIoInventory = require "inventory.to-io-inventory"
local transferItems = require "inventory.transfer-items"

---@param from Inventory
---@param to InputOutputInventory
---@param rate? integer
---@return table<string, integer> transferred
local function pushOutput(from, to, rate)
    ---@type table<string, integer>
    local transferrable = {}

    for item, stock in pairs(to.output.stock) do
        local fromStock = from.stock[item]

        if stock.count < stock.maxCount and fromStock and fromStock.count > 0 then
            transferrable[item] = math.min(stock.maxCount - stock.count, fromStock.count)
        end
    end

    return transferItems(from, to.output, transferrable, rate)
end

---@param from InputOutputInventory
---@param to Inventory
---@param transferredOutput table<string, integer>
---@param rate? integer
---@return table<string, integer> transferred
local function pullInput(from, to, transferredOutput, rate)
    ---@type table<string, integer>
    local transferrable = {}

    for item, stock in pairs(from.input.stock) do
        local maxStock = stock.maxCount

        if from.output.stock[item] then
            maxStock = maxStock + from.output.stock[item].maxCount
        end

        maxStock = maxStock - (transferredOutput[item] or 0)

        local toStock = to.stock[item]

        if toStock then
            maxStock = maxStock - toStock.count
        end

        transferrable[item] = math.min(stock.count, maxStock)
    end

    return transferItems(from.input, to, transferrable, rate, true)
end

local function findChestSide()
    return findPeripheralSide("minecraft:chest")
end

local function dumpChestcartToBarrel()
    while suck() do
    end

    if not dump("bottom") then
        error("buffer barrel full")
    end

    if suck() then
        dumpChestcartToBarrel()
    end
end

local function dumpBarrelToChestcart()
    while suck("bottom") do
    end

    if not dump("front") then
        -- [todo] recover from error. this should only happen when buffer already had items in it
        -- before chestcart arrived
        error("chestcart full")
    end

    if suck("bottom") then
        dumpBarrelToChestcart()
    end
end

local function waitForChestcart()
    os.sleep(1)
    if not Backpack.selectItem("minecraft:redstone_block") then
        error("my redstone block went missing :(")
    end

    print("waiting for chestcart...")
    os.pullEvent("redstone")
    print("chestcart is here! locking it in place...")

    if not place() then
        error("could not place redstone block to lock piston :(")
    end
end

local function lookAtChestcart()
    local signal = Redstone.getInput({"left", "right"})

    if signal then
        -- turn towards the chestcart
        turn(signal)
    else
        -- unlock piston in case there is no chestcart
        dig()
    end
end

local function emptyChestcart()
    if not Redstone.getInput("front") then
        print("looking at rail, but no chestcart here. turning towards piston")
        local chest = findChestSide()

        if chest == "left" then
            turn("right")
        else
            turn("left")
        end
    else
        dumpChestcartToBarrel()
        local chest = findChestSide()
        turn(chest)
    end
end

local function doIO()
    print("doing I/O...")
    local io = findChestSide()
    local barrel = toInventory("bottom")
    local ioChest = toIoInventory(io)
    local transferredStock = pushOutput(barrel, ioChest)
    local movedAnyOutput = count(transferredStock) > 0
    local transferredInputStock = pullInput(ioChest, barrel, transferredStock)
    local movedAnyInput = count(transferredInputStock) > 0

    if not movedAnyInput and not movedAnyOutput then
        print("didn't transfer anything, sleeping 7s")
        os.sleep(7)
    end

    local signal = Redstone.getInput({"left", "right"})

    if not signal then
        error("chestcart vanished :(")
    end

    turn(signal)
    print("filling chestcart...")
    dumpBarrelToChestcart()
    print("sending off chestcart!")
    turn(signal)
    dig()
    os.sleep(3)
end

---@param args table
---@return boolean success
local function main(args)
    print("[io-chestcart v1.3.0] booting...")

    if not inspect("bottom", "minecraft:barrel") then
        error("no barrel at bottom")
    end

    while true do
        local front = inspect()

        if front and front.name == "minecraft:redstone_block" then
            lookAtChestcart();
        elseif front and front.name == "minecraft:detector_rail" then
            emptyChestcart()
        elseif front and front.name == "minecraft:chest" then
            doIO();
        elseif not front and findChestSide() == "back" then
            waitForChestcart()
        end
    end
end

return main(arg)
