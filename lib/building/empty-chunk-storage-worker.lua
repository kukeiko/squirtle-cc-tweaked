local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local Cardinal = require "lib.common.cardinal"
local TurtleTaskWorker = require "lib.system.turtle-task-worker"
local ItemStock = require "lib.inventory.item-stock"
local ItemApi = require "lib.inventory.item-api"
local TurtleApi = require "lib.turtle.turtle-api"
local StorageService = require "lib.inventory.storage-service"
local Resumable = require "lib.turtle.resumable"

---@class EmptyChunkStorageWorker : TurtleTaskWorker 
local EmptyChunkStorageWorker = {}
setmetatable(EmptyChunkStorageWorker, {__index = TurtleTaskWorker})

---@param task EmptyChunkStorageTask
---@param taskService TaskService | RpcClient
---@return EmptyChunkStorageWorker
function EmptyChunkStorageWorker.new(task, taskService)
    local instance = TurtleTaskWorker.new(task, taskService) --[[@as EmptyChunkStorageWorker]]
    setmetatable(instance, {__index = EmptyChunkStorageWorker})

    return instance
end

---@return TaskType
function EmptyChunkStorageWorker.getTaskType()
    return "empty-chunk-storage"
end

---@return EmptyChunkStorageTask
function EmptyChunkStorageWorker:getTask()
    return self.task --[[@as EmptyChunkStorageTask]]
end

function EmptyChunkStorageWorker:work()
    -- local resumable = Resumable.new("empty-chunk-storage-worker")
    local task = self:getTask()
    -- local numShulkers = 4
    local numShulkers = 1

    TurtleApi.locate()
    TurtleApi.orientate("disk-drive")

    if not task.home then
        self:requireFuel(TurtleApi.getFiniteFuelLimit())
        self:requireShulkers(numShulkers)
        task.home = TurtleApi.getPosition()
        task.homeFacing = TurtleApi.getFacing()
        self:updateTask()
    end

    while not task.isEmpty do
        if task.loadUp then
            -- go to chunk storage & load up
            print("[going] to chunk storage...")
            TurtleApi.navigate(TurtleApi.getChunkCenter(task.chunkX, task.y, task.chunkZ))
            TurtleApi.face(Cardinal.south)
            print("[loading] up!")
            local storage = Rpc.nearest(StorageService, nil, "wired")
            local itemDetails = storage.getItemDetails()
            local stock = storage.getStock()
            local sliced, open = TurtleApi.sliceStockForShulkers(stock, itemDetails)
            local total = ItemStock.merge({TurtleApi.getShulkerStock(), sliced})
            TurtleApi.requireItemsFromStorage(total, true)
            task.isEmpty = Utils.isEmpty(open)
            task.loadUp = false
            self:updateTask()
            print("[loaded] up")
        else
            -- go to hub and dump
            print("[going] to hub...")
            TurtleApi.navigate(task.home)
            TurtleApi.face(task.homeFacing)
            print("[dumping] to hub...")
            local stock = ItemStock.subtract(TurtleApi.getStock(true), {[ItemApi.diskDrive] = 1, [ItemApi.shulkerBox] = numShulkers})
            TurtleApi.dumpToStorage(stock)
            task.loadUp = true
            self:updateTask()
        end
    end

    print("[dumping] shulkers...")
    TurtleApi.navigate(task.home)
    TurtleApi.face(task.homeFacing)
    local stock = ItemStock.subtract(TurtleApi.getStock(true), {[ItemApi.diskDrive] = 1})
    TurtleApi.dumpToStorage(stock)

    -- resumable:setStart(function()
    --     self:requireFuel(TurtleApi.getFiniteFuelLimit())
    --     self:requireShulkers(numShulkers)

    --     TurtleApi.locate()
    --     TurtleApi.orientate("disk-drive")

    --     ---@class EmptyChunkStorageState
    --     local state = {home = TurtleApi.getPosition(), facing = TurtleApi.orientate("disk-drive")}

    --     return state
    -- end)

    -- resumable:setResume(function()
    --     TurtleApi.locate()
    --     TurtleApi.orientate("disk-drive")
    -- end)

    -- resumable:addMain("load-from-storage", function()
    --     TurtleApi.navigate(TurtleApi.getChunkCenter(task.chunkX, task.y, task.chunkZ))
    --     TurtleApi.face(Cardinal.south)

    --     TurtleApi.connectToStorage(function(inventory, storage)

    --     end)
    -- end)

    -- ---@param state EmptyChunkStorageState
    -- resumable:addMain("dump-to-hub", function(state)
    --     TurtleApi.navigate(state.home)
    --     TurtleApi.face(state.facing)
    --     local stock = ItemStock.subtract(TurtleApi.getStock(true), {[ItemApi.diskDrive] = 1, [ItemApi.shulkerBox] = numShulkers})
    --     TurtleApi.dumpToStorage(stock)
    -- end)

    -- ---@param state EmptyChunkStorageState
    -- resumable:setFinish(function(state)
    --     TurtleApi.navigate(state.home)
    --     TurtleApi.face(state.facing)
    --     local stock = ItemStock.subtract(TurtleApi.getStock(true), {[ItemApi.diskDrive] = 1})
    --     TurtleApi.dumpToStorage(stock)
    -- end)

    -- resumable:run(nil, true)
end

return EmptyChunkStorageWorker
