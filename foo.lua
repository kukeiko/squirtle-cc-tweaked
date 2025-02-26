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
local CraftingApi = require "lib.common.crafting-api"
local TaskService = require "lib.common.task-service"
local AppsService = require "lib.features.apps-service"
local TaskBufferService = require "lib.common.task-buffer-service"

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

function testDanceTask()
    if arg[1] == "dancer" then
        local taskService = Rpc.tryNearest(TaskService)
        local task = taskService.acceptTask(os.getComputerLabel(), "dance") --[[@as DanceTask]]
        turtle.turnLeft()
        turtle.turnRight()
        turtle.turnRight()
        turtle.turnLeft()
        taskService.finishTask(task.id)
    else
        EventLoop.run(function()
            Rpc.host(TaskService)
        end, function()
            print("issueing DanceTask")
            local task = TaskService.dance(os.getComputerLabel(), 1)
            TaskService.deleteTask(task.id)
            print("DanceTask complete!", task.status)
        end)
    end
end

function testTransferItemsTask()
    local taskService = Rpc.tryNearest(TaskService)
    local task = taskService.transferItems({
        issuedBy = os.getComputerLabel(),
        items = {["minecraft:rail"] = 128},
        to = {"minecraft:chest_10"},
        toTag = "input"
    })

    Utils.prettyPrint(task)
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

local function testEventLoopConfigure()
    EventLoop.run(function()
        EventLoop.configure({
            accept = function(event)
                return event == "char"
            end,
            window = window.create(term.current(), 1, 1, term.getSize())
        })

        print(EventLoop.pull())
    end)
end

---@type table<string, CraftingRecipe>
local recipes = {
    ["computercraft:pocket_computer_normal"] = {
        item = "computercraft:pocket_computer_normal",
        quantity = 1,
        ingredients = {["minecraft:stone"] = {1, 2, 3, 4, 6, 7, 9}, ["minecraft:golden_apple"] = {5}, ["minecraft:glass_pane"] = {8}}
    },
    ["minecraft:golden_apple"] = {
        item = "minecraft:golden_apple",
        quantity = 1,
        ingredients = {["minecraft:gold_ingot"] = {1, 2, 3, 4, 6, 7, 8, 9}, ["minecraft:apple"] = {5}}
    },
    ["minecraft:gold_ingot"] = {item = "minecraft:gold_ingot", quantity = 9, ingredients = {["minecraft:gold_block"] = {5}}},
    ["minecraft:gold_block"] = {
        item = "minecraft:gold_block",
        quantity = 1,
        ingredients = {["minecraft:gold_ingot"] = {1, 2, 3, 4, 5, 6, 7, 8, 9}}
    },
    ["minecraft:anvil"] = {
        item = "minecraft:anvil",
        quantity = 1,
        ingredients = {["minecraft:iron_block"] = {1, 2, 3}, ["minecraft:iron_ingot"] = {5, 7, 8, 9}}
    },
    ["minecraft:iron_ingot"] = {item = "minecraft:iron_ingot", quantity = 9, ingredients = {["minecraft:iron_block"] = {5}}},
    ["minecraft:iron_block"] = {
        item = "minecraft:iron_block",
        quantity = 1,
        ingredients = {["minecraft:iron_ingot"] = {1, 2, 3, 4, 5, 6, 7, 8, 9}}
    },
    ["minecraft:redstone_torch"] = {
        item = "minecraft:redstone_torch",
        quantity = 1,
        ingredients = {["minecraft:redstone"] = {2}, ["minecraft:stick"] = {5}}
    },
    ["minecraft:stick"] = {item = "minecraft:stick", quantity = 4, ingredients = {["minecraft:birch_planks"] = {2, 5}}}
}

function testGetCraftingDetails()
    function testRedstoneTorch()
        ---@type ItemStock
        local targetStock = {["minecraft:redstone_torch"] = 4}
        ---@type ItemStock
        local availableStock = {
            ["minecraft:redstone_torch"] = 1,
            ["minecraft:redstone"] = 3,
            ["minecraft:stick"] = 1,
            ["minecraft:birch_planks"] = 2
        }

        return CraftingApi.getCraftingDetails(targetStock, availableStock, recipes)
    end

    local function testAnvil()
        ---@type ItemStock
        local targetStock = {["minecraft:anvil"] = 2}
        ---@type ItemStock
        local availableStock = {["minecraft:iron_ingot"] = 31, ["minecraft:iron_block"] = 3}

        return CraftingApi.getCraftingDetails(targetStock, availableStock, recipes)
    end

    local details = testAnvil()

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

local function testGetCraftableCount()
    local function testRedstoneTorch()
        ---@type ItemStock
        local availableStock = {
            ["minecraft:redstone_torch"] = 1,
            ["minecraft:redstone"] = 3,
            ["minecraft:stick"] = 1,
            ["minecraft:birch_planks"] = 200
        }

        return CraftingApi.getCraftableCount("minecraft:redstone_torch", availableStock, recipes)
    end

    local function testAnvil()
        ---@type ItemStock
        local availableStock = {["minecraft:iron_ingot"] = 35, ["minecraft:iron_block"] = 3}

        return CraftingApi.getCraftableCount("minecraft:anvil", availableStock, recipes)
    end

    print("[craftable]", testRedstoneTorch())
end

local function testGetCraftableStock()
    local storageService = Rpc.nearest(StorageService)
    local craftableStock = storageService.getCraftableStock()
    Utils.prettyPrint(craftableStock)
end

local function testGetRequiredSlotCount()
    local storageService = Rpc.nearest(StorageService)

    print(storageService.getRequiredSlotCount({["minecraft:stick2"] = 129}))
end

local function testCompactBuffer()
    local storageService = Rpc.nearest(StorageService)
    local taskBufferService = Rpc.nearest(TaskBufferService)
    local bufferId = taskBufferService.allocateTaskBuffer(0, 26 * 3)
    local buffer = taskBufferService.getBufferNames(bufferId)
    local storages = storageService.getByType("storage")
    storageService.transfer(storages, "withdraw", buffer, "buffer", {["minecraft:smooth_stone"] = 36})
    Utils.waitForUserToHitEnter("[break] before compact")
    taskBufferService.compact(bufferId)
    Utils.waitForUserToHitEnter("[break] after compact")
    print("[busy] flushing & freeing the buffer")
    taskBufferService.flushBuffer(bufferId)
    taskBufferService.freeBuffer(bufferId)
    print("[done] flushed and freed up the buffer")
end

local function testResizeBufferSmaller()
    local storageService = Rpc.nearest(StorageService)
    local taskBufferService = Rpc.nearest(TaskBufferService)
    local bufferId = taskBufferService.allocateTaskBuffer(0, 26 * 3)
    local buffer = taskBufferService.getBufferNames(bufferId)
    local storages = storageService.getByType("storage")
    storageService.transfer(storages, "withdraw", buffer, "buffer", {["minecraft:smooth_stone"] = 36})
    Utils.waitForUserToHitEnter("[break] before resize to 26")
    taskBufferService.resize(bufferId, 26)
    Utils.waitForUserToHitEnter("[break] after resize to 26")
    print("[busy] flushing & freeing the buffer")
    taskBufferService.flushBuffer(bufferId)
    taskBufferService.freeBuffer(bufferId)
    print("[done] flushed and freed up the buffer")
end

local function testResizeBufferBigger()
    local taskBufferService = Rpc.nearest(TaskBufferService)
    local bufferId = taskBufferService.allocateTaskBuffer(0, 26 * 1)
    Utils.waitForUserToHitEnter("[break] before resize to 26 * 3")
    taskBufferService.resize(bufferId, 26 * 3)
    Utils.waitForUserToHitEnter("[break] after resize to 26 * 3")
    print("[busy] freeing the buffer")
    taskBufferService.freeBuffer(bufferId)
    print("[done] flushed and freed up the buffer")
end

local function testChunkifyUsedRecipes()
    ---@type ItemDetails
    local itemDetails = {
        ["minecraft:stick"] = {displayName = "Stick", maxCount = 4, name = "minecraft:stick"},
        ["minecraft:birch_planks"] = {displayName = "Birch Planks", maxCount = 64, name = "minecraft:birch_planks"}
    }
    ---@type ItemStock
    local availableStock = {["minecraft:birch_planks"] = 64}
    ---@type ItemStock
    local targetStock = {["minecraft:stick"] = 9}
    local craftingDetails = CraftingApi.getCraftingDetails(targetStock, availableStock, recipes)
    local chunkedUsedRecipes = CraftingApi.chunkUsedRecipes(craftingDetails.usedRecipes, 2, itemDetails)
    print(string.format("recipe chunked from %d to %d", #craftingDetails.usedRecipes, #chunkedUsedRecipes))
end

local now = os.epoch("utc")

for _ = 1, 1 do
    testChunkifyUsedRecipes()
end

print("[time]", (os.epoch("utc") - now) / 1000, "ms")
