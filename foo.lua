package.path = package.path .. ";/?.lua"

local Utils = require "lib.tools.utils"
local TurtleApi = require "lib.turtle.turtle-api"
local TurtleShulkerApi = require "lib.turtle.api-parts.turtle-shulker-api"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc";
local ApplicationService = require "lib.system.apps-service"
local TaskService = require "lib.system.task-service"
local DatabaseService = require "lib.database.database-service"
local StorageService = require "lib.inventory.storage-service"
local CraftingApi = require "lib.inventory.crafting-api"
local EditEntity = require "lib.ui.edit-entity"
local ItemStock = require "lib.inventory.item-stock"
local readInteger = require "lib.ui.read-integer"
local Shell = require "lib.system.shell"
local ItemApi = require "lib.inventory.item-api"
local TurtleInventoryService = require "lib.turtle.turtle-inventory-service"
local requireItems = require "lib.turtle.functions.require-items"
local InventoryApi = require "lib.inventory.inventory-api"
local InventoryLocks = require "lib.inventory.inventory-locks"
local TaskWorkerPool = require "lib.system.task-worker-pool"
local BuildChunkStorageTaskWorker = require "lib.building.build-chunk-storage-worker"
local DigChunkWorker = require "lib.digging.dig-chunk-worker"
local BuildChunkPylonWorker = require "lib.building.build-chunk-pylon-worker"
local buildChunkStorage = require "lib.building.build-chunk-storage"
local toBuildChunkPylonIterations = require "lib.building.to-build-chunk-pylon-iterations"
local duck = require "duck"

local function testGetCraftingDetails()
    local function testCampfires()
        local storageService = Rpc.nearest(StorageService)
        local databaseService = Rpc.nearest(DatabaseService)
        local recipes = databaseService.getCraftingRecipes()
        local storageStock = storageService.getStock()
        return CraftingApi.getCraftingDetails({["minecraft:campfire"] = 512}, storageStock, recipes)
    end

    local details = testCampfires()
    -- local details = testRedstoneTorch()
    -- local details = testAnvil()

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

local function testGetCraftableStock()
    local storageService = Rpc.nearest(StorageService)
    local craftableStock = storageService.getCraftableStock()
    Utils.prettyPrint(craftableStock)
end

local function testGetRequiredSlotCount()
    local storageService = Rpc.nearest(StorageService)

    print(storageService.getRequiredSlotCount({["minecraft:stick"] = 129}))
end

-- local function testCompactBuffer()
--     local storageService = Rpc.nearest(StorageService)
--     local taskBufferService = Rpc.nearest(TaskBufferService)
--     local bufferId = taskBufferService.allocateTaskBuffer(0, 26 * 3)
--     local buffer = taskBufferService.getBufferNames(bufferId)
--     local storages = storageService.getByType("storage")
--     storageService.transfer(storages, "withdraw", buffer, "buffer", {["minecraft:smooth_stone"] = 36})
--     Utils.waitForUserToHitEnter("[break] before compact")
--     taskBufferService.compact(bufferId)
--     Utils.waitForUserToHitEnter("[break] after compact")
--     print("[busy] flushing & freeing the buffer")
--     taskBufferService.flushBuffer(bufferId)
--     taskBufferService.freeBuffer(bufferId)
--     print("[done] flushed and freed up the buffer")
-- end

-- local function testResizeBufferSmaller()
--     local storage = Rpc.nearest(StorageService)
--     local taskBufferService = Rpc.nearest(StorageService)
--     local bufferId = taskBufferService.allocateTaskBuffer(0, 26 * 3)
--     local buffer = taskBufferService.getBufferNames(bufferId)
--     local storages = storage.getByType("storage")
--     storage.transfer(storages, "withdraw", buffer, "buffer", {["minecraft:smooth_stone"] = 36})
--     Utils.waitForUserToHitEnter("[break] before resize to 26")
--     taskBufferService.resize(bufferId, 26)
--     Utils.waitForUserToHitEnter("[break] after resize to 26")
--     print("[busy] flushing & freeing the buffer")
--     taskBufferService.flushBuffer(bufferId)
--     taskBufferService.freeBuffer(bufferId)
--     print("[done] flushed and freed up the buffer")
-- end

local function testResizeBufferBigger()
    local storage = Rpc.nearest(StorageService)
    local bufferId = storage.allocateTaskBuffer(0, 26 * 1)
    Utils.waitForUserToHitEnter("[break] before resize to 26 * 3")
    storage.resize(bufferId, 26 * 3)
    Utils.waitForUserToHitEnter("[break] after resize to 26 * 3")
    print("[busy] freeing the buffer")
    storage.freeBuffer(bufferId)
    print("[done] flushed and freed up the buffer")
end

local function testInventoryLocks()
    local _, releaseABC, lockId = InventoryLocks.lock({"a", "b", "c"})
    print("[locked] A, B, C")

    EventLoop.run(function()
        local _, releaseB = InventoryLocks.lock({"b"}, lockId)
        print("[locked] B")
        os.sleep(1)
        releaseB()
    end, function()
        os.sleep(1)
        print("[releasing] A, B, C")
        releaseABC()
        local _, releaseB = InventoryLocks.lock({"b"})
        print("[locked] B")
        releaseB();
    end)
end

local function testSuckSlot()
    os.sleep(1)
    print(TurtleApi.suckItem("bottom", "minecraft:glass", 96))
end

local function testEditEntity()
    ---@type SubwayStation
    local subwayStation = {id = "foo", name = "Foo Bahnhof", type = "hub", tracks = {}}
    local editEntity = EditEntity.new()

    ---@type SubwayStationType[]
    local types = {"hub", "endpoint", "platform", "switch"}

    editEntity:addField("string", "id", "Id")
    editEntity:addField("string", "name", "Name")
    editEntity:addField("string", "type", "Type", {values = types})
    editEntity:addField("integer", "foo", "Foo")

    local result = editEntity:run(subwayStation)
    Utils.prettyPrint(result)
end

local function testEditEntityWithShell()
    Shell:addWindow("Foo", function()
        ---@type SubwayStation
        local subwayStation = {id = "foo", name = "Foo Bahnhof", type = "hub", tracks = {}}
        local editEntity = EditEntity.new("Edit Subway")

        ---@type SubwayStationType[]
        local types = {"hub", "endpoint", "platform", "switch"}

        editEntity:addField("string", "id", "Id")
        editEntity:addField("string", "name", "Name")
        editEntity:addField("string", "type", "Type", {values = types})
        editEntity:addField("integer", "foo", "Foo")

        local result = editEntity:run(subwayStation)
        Utils.prettyPrint(result)
        Utils.waitForUserToHitEnter("<hit enter to continue>")
    end)
    Shell:addWindow("Bar", function()
        print("hello, this is Bar!")
        EventLoop.pullKey(keys.enter)

        Shell:addWindow("Baz", function()
            print("hello, this is Baz!")
            EventLoop.pullKey(keys.enter)
        end)
    end)
    Shell:run()

end

local function testShell()
    Shell:addWindow("Foo", function()
        print("hello, this is Foo!")
        os.sleep(1)
        -- EventLoop.pullKey(keys.enter)
    end)
    Shell:addWindow("Bar", function()
        print("hello, this is Bar!")
        EventLoop.pullKey(keys.enter)

        Shell:addWindow("Baz", function()
            print("hello, this is Baz!")
            EventLoop.pullKey(keys.enter)
        end)
    end)
    Shell:run()
end

local function testStorageUsingTurtleInventory()
    EventLoop.run(function()
        Rpc.host(TurtleInventoryService, "wired")
    end, function()
        Utils.waitForUserToHitEnter("<hit enter to transfer>")
        local storage = Rpc.nearest(StorageService)
        local storages = storage.getByType("storage")
        storage.fulfill(storages, {TurtleInventoryService.host}, {[ItemApi.diskDrive] = 1})
        Utils.waitForUserToHitEnter("<hit enter to transfer back>")
        storage.empty({TurtleInventoryService.host}, storages)
    end)
end

local function testReadShulkers()
    -- TurtleApi.requireItems({[ItemApi.smoothStone] = 3}, true)
    Utils.waitForUserToHitEnter("read #1")
    TurtleApi.readShulkers()
    Utils.waitForUserToHitEnter("read #2")
    local shulkers = TurtleApi.readShulkers()
    Utils.writeJson("foo.json", shulkers)
end

local function testLoadFromShulker()
    TurtleApi.loadFromShulker(ItemApi.smoothStone)
    TurtleApi.loadFromShulker(ItemApi.stone)
end

local function testGetRequiredShulkers()
    local additionalShulkers = TurtleShulkerApi.getRequiredAdditionalShulkers(TurtleApi, {[ItemApi.smoothStone] = 3455})
    print(string.format("need %dx more shulkers", additionalShulkers))
end

local function testLoadShulkers()
    local success = TurtleApi.tryLoadShulkers()
    print(success)
end

local function testTransferItem()
    EventLoop.run(function()
        InventoryApi.discover()
        InventoryApi.start()
    end, function()
        local _, unlock = InventoryLocks.lock({"minecraft:chest_94"})
        os.sleep(7)
        unlock()
        print("[unlocked]")
    end, function()
        local from = {"minecraft:chest_94", "minecraft:chest_95"}
        local to = {"minecraft:chest_96", "minecraft:chest_97"}
        local stock = {[ItemApi.smoothStone] = 128}
        InventoryApi.transfer(from, to, stock, {fromTag = "output", toTag = "input"})
    end)
end

local function testItemApiGetRequiredSlotCount()
    local slots = ItemApi.getRequiredSlotCount({[ItemApi.shulkerBox] = 65}, 64)
    print(slots)
end

local function testGetChunkCenter()
    print(TurtleApi.getChunkCenter(-2, 1, 1))
end

local function testWriteStorageFloppy()
    local appService = Rpc.nearest(ApplicationService)
    local storageApp = appService.getComputerApp(true, "storage")

    TurtleApi.up()
    TurtleApi.put("front", ItemApi.diskDrive)

    while not TurtleApi.selectItem(ItemApi.disk) do
        TurtleApi.requireItem(ItemApi.disk)
    end

    TurtleApi.drop("front")
    local storageFile = fs.open("disk/storage", "w")
    storageFile.write(storageApp.content)
    storageFile.close()

    local storageStartupFile = fs.open("disk/storage-startup", "w")
    storageStartupFile.write("shell.run(\"storage\")")
    storageStartupFile.close()

    local startupFile = fs.open("disk/startup", "w")
    startupFile.write("shell.run(\"copy disk/storage storage\")")
    startupFile.write("shell.run(\"copy disk/storage-startup startup\")")
    local computerLabel = string.format("Chunk Storage %d-%d")
    startupFile.write("shell.run(\"label set \\\"Chunk Storage\\\" \")")
    startupFile.close()

    TurtleApi.down()
    local computerIsOn = peripheral.call("front", "isOn")
    peripheral.call("front", computerIsOn and "reboot" or "turnOn")

    TurtleApi.up()
    TurtleApi.suck()
    TurtleApi.dig()
    TurtleApi.down()
    peripheral.call("front", "reboot")
end

local function testStorageServiceViaWiredModem()
    TurtleApi.connectToStorage(function(inventory, storage)
        Utils.prettyPrint(storage.getStock())
        local storages = storage.getByType("storage")
        storage.empty({inventory}, storages)
        -- storage.fulfill(storages, {inventory}, {[ItemApi.barrel] = 2})
    end)
end

local function testBuildChunkStorage()
    local results = TurtleApi.simulate(function()
        buildChunkStorage("", 1)
    end)

    TurtleApi.requireItems(results.placed)
    print("steps", results.steps)
    TurtleApi.refuelTo(results.steps)

    buildChunkStorage("Foo Bar", 1)
end

local function testBuildChunkStorageWorker()
    local taskService = Rpc.nearest(TaskService)

    EventLoop.run(function()
        TaskWorkerPool.new(BuildChunkStorageTaskWorker, 1):run()
    end, function()
        os.sleep(1)
        taskService.buildChunkStorage({
            issuedBy = "foo",
            chunkX = 3,
            chunkZ = 1,
            y = 60,
            chestLayers = 1,
            skipAwait = true,
            autoDelete = true
        })
        -- taskService.buildChunkStorage({issuedBy = "foo", chunkX = 0, chunkY = 0, skipAwait = true, label = tostring(os.epoch("utc"))})
    end)
end

local function testDigChunkStorageWorker()
    local taskService = Rpc.nearest(TaskService)

    EventLoop.run(function()
        TaskWorkerPool.new(DigChunkWorker, 1):run()
    end, function()
        os.sleep(1)
        taskService.digChunk({issuedBy = "foo", chunkX = 3, chunkZ = 1, y = 60, skipAwait = true, autoDelete = true})
    end)
end

local function testBuildChunkPylonWorker()
    local taskService = Rpc.nearest(TaskService)

    EventLoop.run(function()
        TaskWorkerPool.new(BuildChunkPylonWorker, 1):run()
    end, function()
        os.sleep(1)
        taskService.buildChunkPylon({issuedBy = "foo", chunkX = 3, chunkZ = 1, y = 60, skipAwait = true, autoDelete = false})
    end)
end

local function testEmptyTurtleToStorage()
    local stock = TurtleApi.getStock(true)
    TurtleApi.dumpToStorage(stock)
end

local function testRequireItems()
    -- requireItems(TurtleApi, {[ItemApi.smoothStone] = (27 * 64 * 1) + 1}, true)
    requireItems(TurtleApi, {[ItemApi.smoothStone] = (3 * 64 * 1) + 1})
end

local function testToBuildChunkPylonIterations()
    local iterations = toBuildChunkPylonIterations({ItemApi.stone}, {[ItemApi.stone] = 16 * 16 * 7}, 1)
    Utils.prettyPrint(iterations)
end

local now = os.epoch("utc")

EventLoop.run(function()
    -- testRequireItems()
    -- testBuildChunkStorage()
    -- testBuildChunkStorageWorker()
    -- testDigChunkStorageWorker()
    -- testEmptyTurtleToStorage()
    -- testToBuildChunkPylonIterations()
    testBuildChunkPylonWorker()

    -- duck()

    -- TurtleApi.buildTripleFloor(5, 3, ItemApi.smoothStone)
    -- local stock = {[ItemApi.cobblestone] = 64 * 1}

    -- TurtleApi.connectToStorage(function(inventory, storage)
    --     EventLoop.run(function()
    --         TurtleApi.requireItems(stock, true)
    --     end, function()
    --         while true do
    --             local openStock = ItemStock.subtract(stock, TurtleApi.getStock(true))
    --             storage.transfer(storage.getByType("storage"), {inventory}, openStock)

    --             if Utils.isEmpty(openStock) then
    --                 break
    --             end
    --         end
    --     end)
    -- end)
end)

print("[time]", (os.epoch("utc") - now) / 1000, "ms")
