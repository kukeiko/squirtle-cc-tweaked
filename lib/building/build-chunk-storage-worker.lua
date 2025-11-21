local EventLoop = require "lib.tools.event-loop"
local Cardinal = require "lib.common.cardinal"
local TaskWorker = require "lib.system.task-worker"
local ItemApi = require "lib.inventory.item-api"
local TurtleApi = require "lib.turtle.turtle-api"
local Resumable = require "lib.turtle.resumable"
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
    local resumable = Resumable.new("build-chunk-storage-worker")
    local task = self:getTask()
    local storageComputerLabel = string.format("Chunk Storage %d/%d", task.chunkX, task.chunkZ)

    resumable:setStart(function(_, options)
        -- [todo] ❌ assert that turtle is connected to turtle hub
        -- [todo] ❌ clean out any unneeded items

        local results = TurtleApi.simulate(function()
            buildChunkStorage(storageComputerLabel)
        end)

        local requiredItems, requiredShulkers = TurtleApi.getOpenStock(results.placed, true)
        local requiredCharcoal = ItemApi.getRequiredRefuelCount(ItemApi.charcoal, TurtleApi.missingFuel())

        TurtleApi.connectToStorage(function(inventory)
            if requiredCharcoal > 0 then
                print("[issuing] charcoal", requiredCharcoal)
                self:provideItems({[ItemApi.charcoal] = requiredCharcoal}, {inventory}, "charcoal")
                TurtleApi.refuelTo(TurtleApi.getFiniteFuelLimit())
            end

            EventLoop.run(function()
                -- [todo] ❌ use logger instead
                -- print("[requiring] items...")
                -- [todo] ❌ is this sleep really required?
                os.sleep(1)
                TurtleApi.requireItems(requiredItems, true)
            end, function()
                if requiredShulkers then
                    -- print("[issuing] shulkers...")
                    self:provideItems({[ItemApi.shulkerBox] = requiredShulkers}, {inventory}, "shulkers")
                end

                -- print("[issuing] items...")
                self:provideItems(requiredItems, {inventory}, "materials", true)

                -- [todo] ❌ fetch more shulkers so the turtle can dig bigger parts of the chunk at once
            end)
        end)

        TurtleApi.locate()
        TurtleApi.orientate("disk-drive")

        ---@class BuildChunkStorageState
        local state = {home = TurtleApi.getPosition(), facing = TurtleApi.orientate("disk-drive")}

        return state
    end)

    resumable:setResume(function(state, resumed)
        TurtleApi.locate()
        TurtleApi.orientate("disk-drive")
    end)

    resumable:addMain("navigate", function(state)
        local task = self:getTask()
        TurtleApi.navigate(TurtleApi.getChunkCenter(task.chunkX, task.y, task.chunkZ))
        TurtleApi.face(Cardinal.south)
    end)

    resumable:addSimulatableMain("build", function(state)
        buildChunkStorage(storageComputerLabel)
    end)

    resumable:addMain("dump", function(state)
        -- [todo] ❌ dump inventory (except shulkers + disk drive) to storage
    end)

    ---@param state BuildChunkStorageState
    resumable:setFinish(function(state, aborted)
        TurtleApi.navigate(state.home)
        TurtleApi.face(state.facing)
    end)

    resumable:run()
end

return BuildChunkStorageTaskWorker
