local ccPretty = "cc.pretty"
local Pretty = require(ccPretty)
package.path = package.path .. ";/?.lua"

local Utils = require "lib.common.utils"
local Vector = require "lib.common.vector"
local Cardinal = require "lib.common.cardinal"
local Squirtle = require "lib.squirtle.squirtle-api"
local EventLoop = require "lib.common.event-loop"
local Inventory = require "lib.inventory.inventory-api"
local Rpc = require "lib.common.rpc";
local SquirtleService = require "lib.squirtle.squirtle-service"
local BoneMealService = require "lib.features.bone-meal-service"
local StorageService = require "lib.features.storage.storage-service"
local SearchableList = require "lib.ui.searchable-list"
local readInteger = require "lib.ui.read-integer"
local CrafterService = require "lib.features.crafter-service"
local QuestService = require "lib.common.quest-service"
local AppsService = require "lib.features.apps-service"

---@param width number
local function countLineBlocks(width)
    local height = math.ceil(width / 2)
    local count = 0

    for layer = 1, height do
        for column = 1, width - ((layer - 1) * 2) do
            count = count + 1
        end
    end

    return count
end

---@param width number
local function countPyramidBlocks(width)
    local count = 0

    local delta = 0
    for line = 1, math.floor(width / 2) do
        count = count + countLineBlocks(line + delta)
        delta = delta + 1
    end

    if width > 1 then
        count = count * 2
    end

    count = count + countLineBlocks(width)

    return count
end
-- 1 => 0
-- 2 => +1
-- 3 => +2
-- 4 => +3

-- local width = tonumber(arg[1]) or 1
-- print(countPyramidBlocks(width))

-- if arg[1] then
--     Rpc.server(StorageService, "bottom")
-- else
--     local storage = Rpc.nearest(StorageService, "bottom")
--     Squirtle.getStacks()
--     storage.createTurtleInventory()
--     os.sleep(1)
--     storage.off()
-- end
-- local furnace = Inventory.create("top")
-- print(Inventory.hasSpaceForItem(furnace, "minecraft:lava_bucket"))

-- Squirtle.move("forward")
-- Squirtle.navigate(pos)
-- print(Squirtle.suckSlot("bottom", 2))
-- print(Squirtle.select("minecraft:barrel"))

-- Squirtle.pullInput_v2(toIoInventory("front"), Inventory.create("bottom"))

-- for _ = 1, 100 do
--     turtle.getItemSpace(1)
-- end

-- Squirtle.face(Cardinal.north)
-- print(Squirtle.selectEmpty(tonumber(arg[1])))

-- Squirtle.setBreakable(function(block)
--     return true
-- end)
-- print(Squirtle.place("minecraft:hopper"))

-- local value = table.pack(client.getTracks())
-- Utils.prettyPrint(value)

-- AppsService.folder = "test-apps"
-- local client = Rpc.nearest(AppsService)
-- AppsService.setComputerApps(client.getComputerApps(true), true)

-- ---@type SubwayStation
-- local subwayStation = {id = "foo", name = "Foo Bahnhof", type = "hub"}
-- local editEntity = EditEntity.new()

-- ---@type SubwayStationType[]
-- local types = {"hub", "endpoint", "platform", "switch"}

-- editEntity:addField("string", "id", "Id")
-- editEntity:addField("string", "name", "Name")
-- editEntity:addField("string", "type", "Type", {values = types})

-- local result = editEntity:run(subwayStation)
-- Utils.prettyPrint(result)

-- Inventories.mount("top")

-- print("[push]")
-- local pushed, open = Squirtle.pushOutput("bottom", "front")
-- Utils.prettyPrint(pushed)
-- Utils.prettyPrint(open)

-- EventLoop.waitForAny(function()
--     Inventory.start()
-- end, function()
--     os.sleep(1)
--     -- local itemStock = Inventories.getStockByTag("front", "input")
--     -- Utils.prettyPrint(itemStock)
--     print("[push]")
--     local pushed, open = Squirtle.pushOutput("bottom", "front")
--     Utils.prettyPrint(pushed)
--     Utils.prettyPrint(open)
--     -- print("[pull]")
--     -- Squirtle.pullInput("front", "bottom", pushed)
-- end)

-- Squirtle.setBreakable(function(block)
--     return block.name ~= "minecraft:stone"
-- end)
-- Squirtle.move("back", 5)
-- Squirtle.turn("back")

-- Squirtle.recover()
-- Squirtle.configure({orientate = "disk-drive"})
-- local pos, facing = Squirtle.orientate(true)

-- print(Cardinal.getName(facing))

-- SquirtleService.host = os.getComputerLabel()
-- Rpc.server(SquirtleService)

-- local occupiedSlots = 0

-- for i = 1, 16 do
--     if turtle.getItemCount(i) > 0 then
--         occupiedSlots = occupiedSlots + 1
--     end
-- end

-- print(occupiedSlots)

function testBoneMealService()
    local host = arg[1] ~= nil

    if host then
        Rpc.host(BoneMealService)
    else
        local client = Rpc.tryNearest(BoneMealService)
        Utils.prettyPrint({client.getStock()})
    end
end

function testStorageService()
    local storage = Rpc.tryNearest(StorageService)

    while true do
        local stock = storage.getStock()
        local nonEmptyStock = Utils.filterMap(stock, function(quantity)
            return quantity > 0
        end)

        local options = Utils.map(nonEmptyStock, function(quantity, item)
            ---@type SearchableListOption
            return {id = item, name = string.format("%dx %s", quantity, item)}
        end)

        table.sort(options, function(a, b)
            return a.id < b.id
        end)

        local titles = {
            "What item ya be needin'?",
            "I've got the goods!",
            "Please pick an Item",
            "Please pick an Item",
            "Please pick an Item"
        }

        local searchableList = SearchableList.new(options, titles[math.random(#titles)])
        local item = searchableList:run()

        if item then
            print("How many?")
            local quantity = readInteger()

            if quantity and quantity > 0 then
                term.clear()
                term.setCursorPos(1, 1)
                print("Transferring...")
                storage.transferItemToStash("Home", item.id, quantity)
                print("Done!")
                os.sleep(1)
            end
        end
    end
end

function testCrafter()
    local questService = Rpc.tryNearest(QuestService)
    print("issuing crafting quest")
    local quest = questService.issueCraftItemQuest(os.getComputerLabel(), "minecraft:redstone_torch", 32)
    print("waiting for completion")
    -- textutils.pagedPrint(textutils.serialiseJSON(quest))
    local lalala = questService.awaitCraftItemQuestCompletion(quest)
    -- textutils.pagedPrint(textutils.serialiseJSON(quest))
    -- Utils.prettyPrint(quest)
    print("quest completed!", lalala.status)
end

function testExpandCraftingItems()
    function testRedstoneTorch()
        ---@type table<string, CraftingRecipe>
        local recipes = {
            ["minecraft:redstone_torch"] = {
                item = "minecraft:redstone_torch",
                quantity = 1,
                ingredients = {["minecraft:redstone"] = {2}, ["minecraft:stick"] = {5}}
            },
            ["minecraft:stick"] = {item = "minecraft:stick", quantity = 4, ingredients = {["minecraft:birch_planks"] = {2, 5}}}
        }

        ---@type ItemStock
        local targetStock = {["minecraft:redstone_torch"] = 4}
        ---@type ItemStock
        local availableStock = {
            ["minecraft:redstone_torch"] = 1,
            ["minecraft:redstone"] = 3,
            ["minecraft:stick"] = 1,
            ["minecraft:birch_planks"] = 2
        }

        return CrafterService.getCraftingDetails(targetStock, availableStock, recipes)
    end

    local details = testRedstoneTorch()

    print("[available]")
    Utils.prettyPrint(details.available)
    Utils.waitForUserToHitEnter()

    print("[unavailable]")
    Utils.prettyPrint(details.unavailable)
    Utils.waitForUserToHitEnter()

    print("[leftover]")
    Utils.prettyPrint(details.leftOver)
    Utils.waitForUserToHitEnter()

    print("[recipes]")
    for i = 1, #details.usedRecipes do
        print(string.format("%dx %s", details.usedRecipes[i].timesUsed, details.usedRecipes[i].item))
    end
    Utils.waitForUserToHitEnter()
end

function testEvents()
    while true do
        print(os.pullEvent())
    end
end

function testUtilsChunk()
    local tbl = {"foo", "bar", "baz"}
    local chunked = Utils.chunk(tbl, 10)

    Utils.prettyPrint(chunked)
end

function testEventLoopRunUntil()
    EventLoop.runUntil("key", function()
        while true do
            print("hello!")
            os.sleep(1)
        end
    end, function()
        while true do
            print("world!")
            os.sleep(1)
        end
    end)
end

function testDanceQuest()
    if arg[1] == "dancer" then
        local questService = Rpc.tryNearest(QuestService)
        local quest = questService.acceptDanceQuest(os.getComputerLabel())
        turtle.turnLeft()
        turtle.turnRight()
        turtle.turnRight()
        turtle.turnLeft()
        questService.finishQuest(quest.id)
    else
        EventLoop.run(function()
            Rpc.host(QuestService)
        end, function()
            print("issueing DanceQuest")
            local quest = QuestService.issueDanceQuest(os.getComputerLabel(), 1)
            quest = QuestService.awaitDanceQuestCompletion(quest)
            print("DanceQuest complete!", quest.status)
        end)
    end
end

function testAllocateQuestBuffer()
    local storageService = Rpc.tryNearest(StorageService)
    ---@type DanceQuest
    local quest = {
        id = 100,
        duration = 1,
        issuedBy = os.getComputerLabel(),
        status = "accepted",
        type = "dance",
        acceptedBy = "hogle-bogle"
    }
    -- local bufferId = storageService.allocateQuestBuffer(quest, 27 * 2)
    local bufferId = storageService.allocateQuestBuffer(quest, 2)
    storageService.transferStockToBuffer(bufferId, {["minecraft:rail"] = 64})
end

function testTransferItemsQuest()
    local questService = Rpc.tryNearest(QuestService)
    local quest = questService.issueTransferItemsQuest(os.getComputerLabel(), {"minecraft:chest_10"}, "input", {["minecraft:rail"] = 128})
    quest = questService.awaitTransferItemsQuestCompletion(quest)
    Utils.prettyPrint(quest)
end

function testUtilsReverse()
    local tbl = {"foo", "bar", "baz"}
    Utils.prettyPrint(Utils.reverse(tbl))
end

function testRunUntil()
    EventLoop.run(function()
        EventLoop.runUntil("key", function()
            while true do
                print("foo")
                os.sleep(1)
            end
        end)
    end, function()
        EventLoop.pull("key")
        print("pulled key")
        EventLoop.queue("foo")
    end, function()
        EventLoop.pull("foo")
        print("pulled foo")
    end)
end

function testMine()
    while true do
        Squirtle.mine()
    end
end

function testSimulateFuel()
    local initialFuel = Squirtle.getNonInfiniteFuelLevel()
    Squirtle.move("forward", 3)
    os.sleep(1)
    turtle.refuel(1)
    local currentFuel = Squirtle.getNonInfiniteFuelLevel()

    Squirtle.simulate({facing = Cardinal.north, fuel = initialFuel, position = Vector.create(0, 0, 0)},
                      {facing = Cardinal.north, fuel = currentFuel, position = Vector.create(0, 0, 0)})

    Squirtle.move("forward", 4)
end

function testPullInteger()
    print(EventLoop.pullInteger(0, 22))
end

function testTryPutAtOneOf()
    Squirtle.setBreakable(function(block)
        return block.name == "minecraft:dirt"
    end)
    local placedSide = Squirtle.tryPutAtOneOf(nil, "minecraft:dirt")
    print("[placed]", placedSide)
end

function testPrintingInWindow()
    local original = term.current()
    original.clear()
    local w, h = original.getSize()
    original.setCursorPos(1, h - 1)
    original.write(string.rep("-", w))
    original.setCursorPos(1, h)
    original.write("[app x.y.z]")

    -- original.setCursorPos(1, 1)
    local win = window.create(original, 1, 1, w, h - 2)
    term.redirect(win)

    for i = 1, 20 do
        print(i)
    end
    term.redirect(original)

    os.sleep(3)
end

local function testIoStock()
    local stock = Inventory.getStock({"left"}, "output")
    Utils.prettyPrint(stock)
end

local function testReadInteger()
    local int = readInteger(nil)
    print("[value]", int)
end

---@param isHost boolean
local function testRpc(isHost)
    if isHost then
        EventLoop.run(function()
            BoneMealService.maxDistance = 3
            Rpc.host(BoneMealService)
        end, function()
            local selfClient = Rpc.nearest(BoneMealService)
            print("[distance]", selfClient.distance)
        end)
    else
        local client = Rpc.nearest(BoneMealService, 3)
        print(client.ping())
    end
end

print(os.pullEvent("key"))

