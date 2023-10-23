package.path = package.path .. ";/lib/?.lua"

local findPeripheralSide = require "world.peripheral.find-side"
local Redstone = require "world.redstone"
local SquirtleV2 = require "squirtle.squirtle-v2"
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
    while SquirtleV2.suck() do
    end

    if not SquirtleV2.dump("bottom") then
        error("buffer barrel full")
    end

    if SquirtleV2.suck() then
        dumpChestcartToBarrel()
    end
end

local function dumpBarrelToChestcart()
    while SquirtleV2.suck("bottom") do
    end

    if not SquirtleV2.dump("front") then
        -- [todo] recover from error. this should only happen when buffer already had items in it
        -- before chestcart arrived
        error("chestcart full")
    end

    if SquirtleV2.suck("bottom") then
        dumpBarrelToChestcart()
    end
end

local function waitForChestcart()
    os.sleep(1)
    print("waiting for chestcart...")
    os.pullEvent("redstone")
    print("chestcart is here! locking it in place...")
    SquirtleV2.placeFront("minecraft:redstone_block")
end

local function lookAtChestcart()
    local signal = Redstone.getInput({"left", "right"})

    if signal then
        -- turn towards the chestcart
        SquirtleV2.turn(signal)
    else
        -- unlock piston in case there is no chestcart
        SquirtleV2.dig()
    end
end

local function emptyChestcart()
    if not Redstone.getInput("front") then
        print("looking at rail, but no chestcart here. turning towards piston")
        local chest = findChestSide()

        if chest == "left" then
            SquirtleV2.turn("right")
        else
            SquirtleV2.turn("left")
        end
    else
        dumpChestcartToBarrel()
        local chest = findChestSide()
        SquirtleV2.turn(chest)
    end
end

---@param name string
---@return boolean
local function hasTransferrableStock(name)
    local ioInventory = toIoInventory(name)

    for _, stock in pairs(ioInventory.input.stock) do
        if (stock.count > 0) then
            return true
        end
    end

    for _, stock in pairs(ioInventory.output.stock) do
        if (stock.count < stock.maxCount) then
            return true
        end
    end

    return false
end

local function fillAndSendOffChestcart()
    local signal = Redstone.getInput({"left", "right"})

    if not signal then
        error("chestcart vanished :(")
    end

    SquirtleV2.turn(signal)
    print("filling chestcart...")
    dumpBarrelToChestcart()
    print("sending off chestcart!")
    SquirtleV2.turn(signal)
    SquirtleV2.dig()
    os.sleep(3)
end

local function doIO()
    local io = findChestSide()

    if not hasTransferrableStock(io) then
        print("waiting until there are items to transfer...")

        repeat
            os.sleep(7 + (math.random() * 3))
        until hasTransferrableStock(io)
    end

    print("transferring items...")
    local ioChest = toIoInventory(io)
    local transferRate = 16
    local barrel = toInventory("bottom")
    local transferredOutput = pushOutput(barrel, ioChest, transferRate)
    local movedAnyOutput = count(transferredOutput) > 0
    local transferredInputStock = pullInput(ioChest, barrel, transferredOutput, transferRate)
    local movedAnyInput = count(transferredInputStock) > 0

    if not movedAnyInput and not movedAnyOutput then
        print("nothing transferred, sleeping 7s...")
        os.sleep(7)
    end

    fillAndSendOffChestcart()
end

---@param args table
---@return boolean success
local function main(args)
    print("[io-chestcart v2.2.0] booting...")

    if not SquirtleV2.inspect("bottom", "minecraft:barrel") then
        error("no barrel at bottom")
    end

    while true do
        local front = SquirtleV2.inspect()

        if front and front.name == "minecraft:redstone_block" then
            lookAtChestcart()
        elseif front and front.name == "minecraft:detector_rail" then
            emptyChestcart()
        elseif front and front.name == "minecraft:chest" then
            doIO()
        elseif not front and findChestSide() == "back" then
            waitForChestcart()
        end
    end
end

return main(arg)
