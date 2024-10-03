local ccPretty = "cc.pretty"
local Pretty = require(ccPretty)
package.path = package.path .. ";/?.lua"

local Utils = require "lib.common.utils"
local Cardinal = require "lib.elements.cardinal"
local Squirtle = require "lib.squirtle"
local EventLoop = require "lib.event-loop"
local Inventory = require "lib.inventory"
local Rpc = require "lib.rpc";
local SquirtleService = require "lib.services.squirtle-service"
local BoneMealService = require "lib.services.bone-meal-service"
local StorageService = require "lib.services.storage-service"
local SearchableList = require "lib.ui.searchable-list"
local readInteger = require "lib.ui.read-integer"
local CrafterService = require "lib.services.crafter-service"
local QuestService = require "lib.common.quest-service"

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
        Rpc.server(BoneMealService)
    else
        local client = Rpc.nearest(BoneMealService)
        Utils.prettyPrint({client.getStock()})
    end
end

function testStorageService()
    local storage = Rpc.nearest(StorageService)

    while true do
        local stock = storage.getStock()
        local nonEmptyStock = Utils.filterMap(stock, function(quantity)
            return quantity > 0
        end)

        local options = Utils.map_v2(nonEmptyStock, function(quantity, item)
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
    os.sleep(3)
    local crafter = Rpc.nearest(CrafterService)
    crafter.craft({
        item = "minecraft:comparator",
        count = 1,
        ingredients = {["minecraft:redstone_torch"] = {2, 4, 6}, ["minecraft:quartz"] = {5}, ["minecraft:stone"] = {7, 8, 9}}
    }, 13)
    -- crafter.craft({
    --     item = "minecraft:redstone_torch",
    --     count = 1,
    --     ingredients = {["minecraft:redstone"] = {5}, ["minecraft:stick"] = {8}}
    -- })
end

function testExpandCraftingItems()
    function testRedstoneTorch()
        ---@type table<string, CraftingRecipe>
        local recipes = {
            ["minecraft:redstone_torch"] = {
                item = "minecraft:redstone_torch",
                count = 1,
                ingredients = {["minecraft:redstone"] = {2}, ["minecraft:stick"] = {5}}
            },
            ["minecraft:stick"] = {item = "minecraft:stick", count = 4, ingredients = {["minecraft:birch_planks"] = {2, 5}}}
        }
        return CrafterService.expandItemStock({["minecraft:redstone_torch"] = 4}, {
            ["minecraft:redstone_torch"] = 1,
            ["minecraft:redstone"] = 3,
            ["minecraft:stick"] = 1,
            ["minecraft:birch_planks"] = 2
        }, recipes)
    end

    local expanded, unavailable, leftover, recipes = testRedstoneTorch()
    Utils.prettyPrint(expanded)
    Utils.prettyPrint(unavailable)
    Utils.prettyPrint(leftover)
    Utils.prettyPrint(recipes)
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
        local questService = Rpc.nearest(QuestService)
        local quest = questService.acceptDanceQuest(os.getComputerLabel())
        turtle.turnLeft()
        turtle.turnRight()
        turtle.turnRight()
        turtle.turnLeft()
        questService.finishQuest(quest.id)
    else
        EventLoop.run(function()
            Rpc.server(QuestService)
        end, function()
            print("issueing DanceQuest")
            local quest = QuestService.issueDanceQuest(os.getComputerLabel(), 1)
            quest = QuestService.awaitDanceQuestCompletion(quest)
            print("DanceQuest complete!", quest.status)
        end)
    end
end

function testAllocateQuestBuffer()
    local storageService = Rpc.nearest(StorageService)
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
    local questService = Rpc.nearest(QuestService)
    local quest = questService.issueTransferItemsQuest(os.getComputerLabel(), {"minecraft:chest_10"}, "input", {["minecraft:rail"] = 128})
    quest = questService.awaitTransferItemsQuestCompletion(quest)
    Utils.prettyPrint(quest)
end

function testUtilsReverse()
    local tbl = {"foo", "bar", "baz"}
    Utils.prettyPrint(Utils.reverse(tbl))
end

testUtilsReverse()
