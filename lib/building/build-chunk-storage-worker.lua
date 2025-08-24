local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local TaskWorker = require "lib.system.task-worker"
local StorageService = require "lib.inventory.storage-service"
local ItemApi = require "lib.inventory.item-api"
local TurtleApi = require "lib.turtle.turtle-api"
local buildChunkStorage = require "lib.building.build-chunk-storage"

---@class BuildChunkStorageTaskWorker : TaskWorker 
local BuildChunkStorageTaskWorker = {}
setmetatable(BuildChunkStorageTaskWorker, {__index = TaskWorker})

---@param task BuildChunkStorageTask
---@param taskService TaskService | RpcClient
---@return BuildChunkStorageTaskWorker
function BuildChunkStorageTaskWorker.new(task, taskService)
    local instance = TaskWorker.new(task, taskService) --[[@as BuildChunkStorageTaskWorker]]
    setmetatable(instance, {__index = BuildChunkStorageTaskWorker})

    return instance
end

---@return TaskType
function BuildChunkStorageTaskWorker.getTaskType()
    return "build-chunk-storage"
end

---@return BuildChunkStorageTask
function BuildChunkStorageTaskWorker:getTask()
    return self.task --[[@as BuildChunkStorageTask]]
end

function BuildChunkStorageTaskWorker:work()
    local storageService = Rpc.nearest(StorageService)

    -- [todo] ❌ assert that turtle is connected to turtle hub
    -- [todo] ❌ clean out any unneeded items
    -- [todo] ❌ issue task to provide basic items (disk drive, shulkers, ...)
    -- [todo] ❌ issue task to provide required items (chest, computer, network cables, ...)

    local results = TurtleApi.simulate(function()
        buildChunkStorage()
    end)

    local requiredItems = TurtleApi.getOpenStock(results.placed, true)
    local requiredCharcoal = ItemApi.getRequiredRefuelCount(ItemApi.charcoal, TurtleApi.missingFuel())

    TurtleApi.connectToStorage(function(inventory)
        if requiredCharcoal > 0 then
            -- [todo] ❌ add option that it should only return if everything got transferred
            print("[issuing] charcoal", requiredCharcoal)
            self:provideItems({[ItemApi.charcoal] = requiredCharcoal}, {inventory}, "charcoal")
            TurtleApi.refuelTo(TurtleApi.getFiniteFuelLimit())
        end

        print("[issuing] shulkers...")
        -- [todo] ❌ add option that it should only return if everything got transferred
        self:provideItems({[ItemApi.shulkerBox] = requiredItems[ItemApi.shulkerBox]}, {inventory}, "shulkers")
        requiredItems[ItemApi.shulkerBox] = nil

        -- [todo] ❌ for dev only
        requiredItems = {[ItemApi.birchLog] = 30 * 64}

        EventLoop.run(function()
            print("[requiring] items...")
            os.sleep(1)
            TurtleApi.requireItems(requiredItems, true)
        end, function()
            print("[issuing] items...")
            -- [todo] ❌ add option that it should only return if everything got transferred
            self:provideItems(requiredItems, {inventory}, "materials", true)
        end)
    end)
end

return BuildChunkStorageTaskWorker
