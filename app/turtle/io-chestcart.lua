package.path = package.path .. ";/lib/?.lua"

local Redstone = require "world.redstone"
local Squirtle = require "squirtle"
local Inventory = require "inventory.inventory"

local function dumpChestcartToBarrel()
    while Squirtle.suck() do
    end

    if not Squirtle.dump("bottom") then
        error("buffer barrel full")
    end

    if Squirtle.suck() then
        dumpChestcartToBarrel()
    end
end

local function dumpBarrelToChestcart()
    while Squirtle.suck("bottom") do
    end

    if not Squirtle.dump("front") then
        -- [todo] recover from error. this should only happen when buffer already had items in it
        -- before chestcart arrived
        error("chestcart full")
    end

    if Squirtle.suck("bottom") then
        dumpBarrelToChestcart()
    end
end

local function waitForChestcart()
    os.sleep(1)
    print("waiting for chestcart...")
    os.pullEvent("redstone")
    print("chestcart is here! locking it in place...")
    Squirtle.put("front", "minecraft:redstone_block")
end

local function lookAtChestcart()
    local signal = Redstone.getInput({"left", "right"})

    if signal then
        -- turn towards the chestcart
        Squirtle.turn(signal)
    else
        -- unlock piston in case there is no chestcart
        Squirtle.mine()
    end
end

local function emptyChestcart()
    if not Redstone.getInput("front") then
        print("looking at rail, but no chestcart here. turning towards piston")
        local chest = Inventory.findChest()

        if chest == "left" then
            Squirtle.turn("right")
        else
            Squirtle.turn("left")
        end
    else
        dumpChestcartToBarrel()
        local chest = Inventory.findChest()
        Squirtle.turn(chest)
    end
end

---@param name string
---@return boolean
local function hasTransferrableStock(name)
    local ioInventory = Inventory.readInputOutput(name)

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

    Squirtle.turn(signal)
    print("filling chestcart...")
    dumpBarrelToChestcart()
    print("sending off chestcart!")
    Squirtle.turn(signal)
    Squirtle.mine()
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
    local _, transferredOutput = Squirtle.pushOutput("bottom", io)
    local _, transferredInput = Squirtle.pullInput(io, "bottom", transferredOutput)

    if not transferredInput and not transferredOutput then
        print("nothing transferred, sleeping 7s...")
        os.sleep(7)
    end

    fillAndSendOffChestcart()
end

---@param args table
---@return boolean success
local function main(args)
    print("[io-chestcart v2.2.0] booting...")

    if not Squirtle.probe("bottom", "minecraft:barrel") then
        error("no barrel at bottom")
    end

    while true do
        local front = Squirtle.probe()
        
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
