if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

local Utils = require "lib.tools.utils"
local Redstone = require "lib.common.redstone"
local TurtleApi = require "lib.turtle.turtle-api"
local Inventory = require "lib.inventory.inventory-api"

local function dumpChestcartToBarrel()
    while TurtleApi.suck() do
    end

    if not TurtleApi.tryDump("bottom") then
        error("buffer barrel full")
    end

    if TurtleApi.suck() then
        dumpChestcartToBarrel()
    end
end

local function dumpBarrelToChestcart()
    while TurtleApi.suck("bottom") do
    end

    if not TurtleApi.tryDump("front") then
        -- [todo] recover from error. this should only happen when buffer already had items in it
        -- before chestcart arrived
        error("chestcart full")
    end

    if TurtleApi.suck("bottom") then
        dumpBarrelToChestcart()
    end
end

local function waitForChestcart()
    os.sleep(1)
    print("waiting for chestcart...")
    os.pullEvent("redstone")
    print("chestcart is here! locking it in place...")
    TurtleApi.put("front", "minecraft:redstone_block")
end

local function lookAtChestcart()
    local signal = Redstone.getInput({"left", "right"})

    if signal then
        -- turn towards the chestcart
        TurtleApi.turn(signal)
    else
        -- unlock piston in case there is no chestcart
        TurtleApi.mine()
    end
end

local function emptyChestcart()
    if not Redstone.getInput("front") then
        print("looking at rail, but no chestcart here. turning towards piston")
        local chest = Inventory.findChest()

        if chest == "left" then
            TurtleApi.turn("right")
        else
            TurtleApi.turn("left")
        end
    else
        dumpChestcartToBarrel()
        local chest = Inventory.findChest()
        TurtleApi.turn(chest)
    end
end

---@param name string
---@return boolean
local function hasTransferrableStock(name)
    local ioInventory = Inventory.read(name, "io")

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

    TurtleApi.turn(signal)
    print("filling chestcart...")
    dumpBarrelToChestcart()
    print("sending off chestcart!")
    TurtleApi.turn(signal)
    TurtleApi.mine()
    os.sleep(3)
end

local function doIO()
    local io = Inventory.findChest()

    if not hasTransferrableStock(io) then
        print("waiting until there are items to transfer...")

        repeat
            os.sleep(7 + (math.random() * 3))
        until hasTransferrableStock(io)
    end

    print("transferring items...")
    local _, transferredOutput = TurtleApi.pushOutput("bottom", io)
    local _, transferredInput = TurtleApi.pullInput(io, "bottom", transferredOutput)

    if Utils.isEmpty(transferredInput) and Utils.isEmpty(transferredOutput) then
        print("nothing transferred, sleeping 7s...")
        os.sleep(7)
    end

    fillAndSendOffChestcart()
end

---@param args table
---@return boolean success
local function main(args)
    print(string.format("[io-chestcart %s] booting...", version()))

    if not TurtleApi.probe("bottom", "minecraft:barrel") then
        error("no barrel at bottom")
    end

    while true do
        local front = TurtleApi.probe()

        if front and front.name == "minecraft:redstone_block" then
            lookAtChestcart()
        elseif front and front.name == "minecraft:detector_rail" then
            emptyChestcart()
        elseif front and front.name == "minecraft:chest" then
            doIO()
        elseif not front and Inventory.findChest() == "back" then
            waitForChestcart()
        end
    end
end

return main(arg)
