package.path = package.path .. ";/lib/?.lua"

local Utils = require "squirtle.libs.utils"
local Side = require "squirtle.libs.side"
local Turtle = require "squirtle.libs.turtle"
local Inventory = require "squirtle.libs.turtle.inventory"

local cropNameToSeedMap = {
    ["minecraft:wheat"] = "minecraft:wheat_seeds",
    ["minecraft:beetroots"] = "minecraft:beetroot_seeds",
    ["minecraft:potatoes"] = "minecraft:potato",
    ["minecraft:carrots"] = "minecraft:carrot"
}

local cropReadyAges = {
    ["minecraft:wheat"] = 7,
    ["minecraft:beetroots"] = 3,
    ["minecraft:potatoes"] = 7,
    ["minecraft:carrots"] = 7
}

local function tryPlantAnything()
    for slot = 1, Inventory.size() do
        if Inventory.selectSlotIfNotEmpty(slot) then
            if Turtle.place() then
                return
            end
        end
    end
end

local function main(args)
    print("[farm-tiles @ 1.0.0]")

    if args[1] == "autorun" then
        Utils.writeAutorunFile({"farm-tiles"})
    end

    local isFirstLoop = true

    while true do
        local block = Turtle.getBlockAt(Side.front)

        if block ~= nil and block.name == "minecraft:snow" then
            print("snow detected, can't deal with that")
        elseif block == nil then
            print("air block found; assuming unexpected shutdown happened while harvesting")
            -- when we encounter an air block it is very likely that the turtle just
            -- resumed from an unexpected shutdown while trying to replant a just harvested
            -- crop. in that case the currently selected slot should be the correct seed to plant.
            if not Turtle.place() then
                -- if that is not the case, we have no option but to try and plant anything else
                -- [todo] not true, if we're currently holding wheat then we should look for seeds
                tryPlantAnything()
            else
                print("successfully resumed from unexpected shutdown")
            end
        elseif block ~= nil and
            (block.name == "minecraft:melon" or block.name == "minecraft:pumpkin") then
            if Turtle.digAt(Side.front) then
                print("harvested melon or pumpkin")
            end
        elseif block ~= nil and block.tags["minecraft:crops"] and block.state.age ==
            cropReadyAges[block.name] then
            local seeds = cropNameToSeedMap[block.name]

            if not seeds then
                error("unsupported crop: " .. block.name)
            end

            Turtle.digAt(Side.front)

            if Inventory.selectItem(seeds) then
                if Turtle.place() then
                    print("success harvest & replant")
                else
                    print("should not happen?")
                end
            else
                print("should'nt happen: no matching seeds found")
                print("trying to place anything")
                tryPlantAnything()
            end
        elseif block ~= nil and block.name == "minecraft:chest" then
            if Inventory.dumpTo(Side.front) then
                -- we've been successful in dumping inventory on first try,
                -- so we didn't spend any time waiting for the chest to get
                -- unloaded. because of that crops are very likely to not
                -- be ready for harvesting, we therefore wait a bit before
                -- checking so that the turtle is not constantly turning
                if isFirstLoop then
                    print("checking tiles immediately as i just started up")
                else
                    print("waiting 60s to give crops time to grow...")
                    os.sleep(60)
                end
            end
            while not Inventory.dumpTo(Side.front) do
                print("chest full, waiting 7s...")
                os.sleep(7)
            end
        end

        isFirstLoop = false
        Turtle.turnRight()
    end
end

return main(arg)