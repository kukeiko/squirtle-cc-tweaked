package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Inventory = require "inventory"
local Squirtle = require "squirtle"
local harvestTree = require "lumberjack.harvest-tree"
local doFurnaceWork = require "lumberjack.do-furnace-work"

local maxLogs = 64
local minBonemeal = 1

---@param type string
---@return string
local function requirePeripheral(type)
    local p = peripheral.find(type)

    if not p then
        error("not found: " .. type)
    end

    return peripheral.getName(p)
end

---@param block Block
---@return string
local function getBlockTurnSide(block)
    if block.name == "minecraft:spruce_fence" then
        return "left"
    elseif block.name == "minecraft:oak_fence" then
        return "right"
    else
        return "left"
    end
end

local function isHome()
    return Squirtle.probe("bottom", "minecraft:barrel") ~= nil
end

local function isAtWork()
    return Squirtle.probe("bottom", {"minecraft:dirt", "minecraft:grass_block"}) ~= nil
end

local function isLookingAtTree()
    return Squirtle.probe("front", {"minecraft:birch_sapling", "minecraft:birch_log"})
end

local function faceHomeExit()
    for _ = 1, 4 do
        if peripheral.hasType("back", "minecraft:furnace") then
            return
        end

        Squirtle.turn("left")
    end

    error("could not face exit: no furnace found")
end

---@param stash string
local function refuel(stash)
    local minFuel = 80 * 65;

    -- [todo] turtle does not make sure to reach min fuel, it happened to me on MP server that
    -- a turtle ran out of fuel while working
    if not Squirtle.hasFuel(minFuel) then
        print(string.format("refueling %s more fuel", Squirtle.missingFuel(minFuel)))
        Squirtle.selectEmpty(1)

        for slot, stack in pairs(Inventory.getStacks(stash)) do
            if stack.name == "minecraft:charcoal" then
                Squirtle.suckSlot("bottom", slot)
                Squirtle.refuel(math.ceil(Squirtle.missingFuel(minFuel) / 80))
            end

            if Squirtle.hasFuel(minFuel) then
                break
            end
        end

        print("refueled to", turtle.getFuelLevel())

        -- in case we reached fuel limit and now have charcoal in the inventory
        if not Squirtle.dump(stash) then
            error("stash full")
        end
    else
        print("have enough fuel:", turtle.getFuelLevel())
    end
end

---@param stash string
---@param io string
local function doInputOutput(stash, io)
    print("[push] output...")
    -- [todo] keep 32 birch saplings
    Squirtle.pushOutput(stash, io)
    print("[pull] input...")
    Squirtle.pullInput(io, stash)

    local isCharcoalFull = function()
        return Inventory.getItemOpenStockByTag(io, "output", "minecraft:charcoal") == 0
    end

    if isCharcoalFull() then
        print("[waiting] for charcoal to drain")

        while isCharcoalFull() do
            os.sleep(3)
        end
    end

    print("[info] output wants more charcoal, want to work now!")

    local needsMoreBoneMeal = function()
        return Inventory.getItemStockByTag(stash, "output", "minecraft:bone_meal") < 64
    end

    if needsMoreBoneMeal() then
        print("[waiting] for more bone meal to arrive")

        while needsMoreBoneMeal() do
            os.sleep(3)
            Squirtle.pullInput(io, stash)
        end
    end

    print("[ready] input looks good!")
end

---@param stash string
local function drainDropper(stash)
    repeat
        local totalItemStock = Inventory.getItemsStock(stash)
        redstone.setOutput("bottom", true)
        os.sleep(.25)
        redstone.setOutput("bottom", false)
    until Inventory.getItemsStock(stash) == totalItemStock
end

---@param stash string
---@param io string
---@param furnace string
local function doHomework(stash, io, furnace)
    print("i am home! dumping inventory to stash...")

    if not Squirtle.dump(stash) then
        error("stash is full :(")
    end

    doFurnaceWork(furnace, stash, io)
    refuel(stash)
    drainDropper(stash)
    doInputOutput(stash, io)

    while Squirtle.suck(stash) do
    end

    local backpackStock = Squirtle.getStock()

    if not backpackStock["minecraft:birch_sapling"] then
        error("out of birch saplings :(")
    end

    if not backpackStock["minecraft:bone_meal"] then
        error("out of bone meal :(")
    end
end

local function plantTree()
    print("planting tree...")
    Squirtle.walk("back")
    Squirtle.put("front", "minecraft:birch_sapling")

    while not Squirtle.probe("front", "minecraft:birch_log") and Squirtle.selectItem("minecraft:bone_meal") do
        Squirtle.place()
    end

    return Squirtle.probe("front", "minecraft:birch_log")
end

local function shouldPlantTree()
    local stock = Squirtle.getStock()
    local needsMoreLogs = (stock["minecraft:birch_log"] or 0) < maxLogs
    local hasBoneMeal = (stock["minecraft:bone_meal"] or 0) >= minBonemeal
    local hasSaplings = (stock["minecraft:birch_sapling"] or 0) > 0

    return hasSaplings and needsMoreLogs and hasBoneMeal
end

local function refuelFromBackpack()
    while Squirtle.missingFuel() > 0 and Squirtle.selectItem("minecraft:stick") do
        print("refueling from sticks...")
        Squirtle.refuel()
    end

    local saplingStock = Squirtle.getStock()["minecraft:birch_sapling"] or 0

    print("refueling from saplings...")
    while Squirtle.missingFuel() > 0 and saplingStock > 64 do
        Squirtle.selectItem("minecraft:birch_sapling")
        Squirtle.refuel(saplingStock - 64)
        saplingStock = Squirtle.getStock()["minecraft:birch_sapling"] or 0
    end

    print("condensing backpack...")
    Squirtle.condense() -- need to condense because we are not selecting saplings in reverse order (which we should)
end

local function doWork()
    print("doing work!")
    assert(isAtWork(), "expected to sit on top of dirt")

    if Squirtle.probe("top", "minecraft:birch_log") then
        -- should only happen if turtle crashed while planting a tree
        harvestTree()
    end

    while shouldPlantTree() do
        if plantTree() then
            Squirtle.select(1)
            Squirtle.dig()
            Squirtle.walk()
            harvestTree()
            refuelFromBackpack()
        else
            -- this case should only happen when bone meal ran out before sapling could be grown
            Squirtle.dig()
            Squirtle.walk()
            break
        end
    end

    print("work finished! going home")
end

local function main()
    print("[lumberjack v2.0.1-dev.0] booting...")
    Squirtle.setBreakable({"minecraft:birch_log", "minecraft:birch_leaves", "minecraft:birch_sapling"})

    -- recover from an interrupted state
    if not isHome() and not isAtWork() then
        print("rebooted while not at home or work")

        if Squirtle.probe("top", "minecraft:birch_log") then
            harvestTree()
        elseif isLookingAtTree() then
            Squirtle.mine()
            Squirtle.move()
        else
            while Squirtle.tryMove("down") do
            end

            if Squirtle.probe("bottom", {"minecraft:spruce_fence", "minecraft:oak_fence", "minecraft:stone_brick_wall"}) then
                -- turtle crashed and landed on the one fence piece that directs it to the tree.
                -- should be safe to move back one, go down, and then resume default move routine
                Squirtle.walk("back")
                Squirtle.walk("down")
            end
        end
    end

    while true do
        if isHome() then
            local stash = requirePeripheral("minecraft:barrel")
            local io = requirePeripheral("minecraft:chest")
            local furnace = requirePeripheral("minecraft:furnace")

            doHomework(stash, io, furnace)
            faceHomeExit()
            Squirtle.move()
        elseif isAtWork() then
            doWork()
            Squirtle.turn("left")
            Squirtle.walk()
        else
            while not Squirtle.tryWalk() do
                local block = Squirtle.probe()

                if not block then
                    error("could not move even though front seems to be free")
                end

                if isLookingAtTree() then
                    -- should only happen if sapling got placed by player
                    Squirtle.mine()
                else
                    Squirtle.turn(getBlockTurnSide(block))
                end
            end
        end
    end
end

return main()
