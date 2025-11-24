local Cardinal = require "lib.common.cardinal"
local TurtleTaskWorker = require "lib.system.turtle-task-worker"
local ItemStock = require "lib.inventory.item-stock"
local ItemApi = require "lib.inventory.item-api"
local TurtleApi = require "lib.turtle.turtle-api"
local Resumable = require "lib.turtle.resumable"
local buildChunkStorage = require "lib.building.build-chunk-storage"

---@class BuildChunkStorageTaskWorker : TurtleTaskWorker 
local BuildChunkStorageTaskWorker = {}
setmetatable(BuildChunkStorageTaskWorker, {__index = TurtleTaskWorker})

---@param task BuildChunkStorageTask
---@param taskService TaskService | RpcClient
---@return BuildChunkStorageTaskWorker
function BuildChunkStorageTaskWorker.new(task, taskService)
    local instance = TurtleTaskWorker.new(task, taskService) --[[@as BuildChunkStorageTaskWorker]]
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
    -- [todo] ❌ assert that turtle is connected to turtle hub
    -- [todo] ❓ clean out any unneeded items before starting?
    -- [todo] ❓ turtle needs disk-drive to connect to storage, but needs storage to get a disk-drive.

    local resumable = Resumable.new("build-chunk-storage-worker")
    local task = self:getTask()
    local storageComputerLabel = string.format("Chunk Storage %d/%d", task.chunkX, task.chunkZ)

    resumable:setStart(function()
        local results = TurtleApi.simulate(function()
            buildChunkStorage(storageComputerLabel, task.chestLayers)
        end)

        local requiredItems, requiredShulkers = TurtleApi.getOpenStock(results.placed, true)
        local totalShulkers = math.max(requiredShulkers, 4)

        self:requireFuel(TurtleApi.getFiniteFuelLimit())
        self:requireShulkers(totalShulkers)
        self:requireItems(requiredItems, "materials")

        TurtleApi.locate()
        TurtleApi.orientate("disk-drive")

        ---@class BuildChunkStorageState
        local state = {home = TurtleApi.getPosition(), facing = TurtleApi.orientate("disk-drive")}

        return state
    end)

    resumable:setResume(function()
        TurtleApi.locate()
        TurtleApi.orientate("disk-drive")
    end)

    resumable:addMain("navigate", function()
        local task = self:getTask()
        TurtleApi.navigate(TurtleApi.getChunkCenter(task.chunkX, task.y, task.chunkZ))
        TurtleApi.face(Cardinal.south)
    end)

    resumable:addSimulatableMain("build", function()
        buildChunkStorage(storageComputerLabel, task.chestLayers)
    end)

    ---@param state BuildChunkStorageState
    resumable:setFinish(function(state)
        TurtleApi.navigate(state.home)
        TurtleApi.face(state.facing)
        local stock = ItemStock.subtract(TurtleApi.getStock(true), {[ItemApi.diskDrive] = 1})
        TurtleApi.dumpToStorage(stock)
    end)

    resumable:run()
end

return BuildChunkStorageTaskWorker
