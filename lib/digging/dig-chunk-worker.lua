local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local Cardinal = require "lib.common.cardinal"
local ItemApi = require "lib.inventory.item-api"
local TurtleTaskWorker = require "lib.system.turtle-task-worker"
local TurtleApi = require "lib.turtle.turtle-api"
local Resumable = require "lib.turtle.resumable"
local ChunkPylonService = require "lib.building.chunk-pylon-service"

---@class DigChunkWorker : TurtleTaskWorker 
local DigChunkWorker = {}
setmetatable(DigChunkWorker, {__index = TurtleTaskWorker})

---@param task DigChunkTask
---@param taskService TaskService | RpcClient
---@return DigChunkWorker
function DigChunkWorker.new(task, taskService)
    local instance = TurtleTaskWorker.new(task, taskService) --[[@as DigChunkWorker]]
    setmetatable(instance, {__index = DigChunkWorker})

    return instance
end

---@return TaskType
function DigChunkWorker.getTaskType()
    return "dig-chunk"
end

---@return DigChunkTask
function DigChunkWorker:getTask()
    return self.task --[[@as DigChunkTask]]
end

function DigChunkWorker:work()
    local resumable = Resumable.new("dig-chunk-worker")
    local task = self:getTask()
    local service = Rpc.nearest(ChunkPylonService)
    local chunkPylon = service.get(task.chunkX, task.chunkZ)
    local firstLayerY = (chunkPylon.lastDugY or task.storageY) - 1
    print("[first] layer", firstLayerY)
    local numShulkers = 4
    local layersPerIteration = (Utils.isDev() and 3) or math.floor((numShulkers * 27 * 64) / (16 * 16) * 0.8)
    local lastLayer = Utils.isDev() and 50 or -59;
    local totalDigHeight = (firstLayerY - lastLayer) + 1
    local iterations = math.ceil(totalDigHeight / layersPerIteration)

    resumable:setStart(function(_, options)
        self:requireFuel(TurtleApi.getFiniteFuelLimit())
        self:requireShulkers(numShulkers)
        TurtleApi.locate()
        TurtleApi.orientate("disk-drive")

        ---@class DigChunkState
        local state = {home = TurtleApi.getPosition(), facing = TurtleApi.orientate("disk-drive")}

        -- [todo] 🧪 setting this flag in addition to fueling to limit to ensure the fuel tank is big enough for the task
        options.requireFuel = true

        return state
    end)

    resumable:setResume(function()
        TurtleApi.locate()
        TurtleApi.orientate("disk-drive")
    end)

    ---@param state DigChunkState
    resumable:addMain("disengage-hub", function(state)
        TurtleApi.navigate(TurtleApi.getHubDockingPosition(state.home))
    end)

    resumable:addMain("navigate", function()
        TurtleApi.navigate(TurtleApi.getChunkCenter(task.chunkX, task.storageY, task.chunkZ))
        TurtleApi.face(Cardinal.south)
    end)

    for i = 1, iterations do
        ---@param state DigChunkState
        resumable:addSimulatableMain(string.format("dig-%d", i), function(state)
            local startY = firstLayerY - ((i - 1) * layersPerIteration)
            local digHeight = Utils.toDigDownHeight(startY, lastLayer, layersPerIteration)

            -- disengage from storage
            TurtleApi.down()

            -- move to start position of current iteration
            local target = TurtleApi.getChunkNorthWest(task.chunkX, startY, task.chunkZ)
            print(string.format("[move] to %d/%d/%d to dig", target.x, target.y, target.z))
            TurtleApi.moveToPoint(target)
            TurtleApi.face(Cardinal.east)

            -- dig out iteration
            TurtleApi.digArea(16, 16, digHeight, nil, nil, function(y)
                -- record last dug layer for faster resume in case of task failure
                service.markLayerDugOut(task.chunkX, task.chunkZ, y)
            end)

            -- move back to storage
            local currentLayerCenter = TurtleApi.getChunkCenter(task.chunkX, TurtleApi.getPosition().y, task.chunkZ)
            print(string.format("[move] to center %d/%d/%d", currentLayerCenter.x, currentLayerCenter.y, currentLayerCenter.z))
            TurtleApi.moveToPoint(currentLayerCenter)

            local storageHome = TurtleApi.getChunkCenter(task.chunkX, task.storageY, task.chunkZ)
            print(string.format("[move] to storage %d/%d/%d", storageHome.x, storageHome.y, storageHome.z))
            TurtleApi.moveToPoint(storageHome)
            TurtleApi.face(Cardinal.south)
        end)

        resumable:addMain(string.format("dump-%d", i), function()
            TurtleApi.dumpAllToStorage({[ItemApi.shulkerBox] = numShulkers, [ItemApi.diskDrive] = 1})
        end)
    end

    ---@param state DigChunkState
    resumable:addMain("engage-hub", function(state)
        TurtleApi.navigate(TurtleApi.getHubDockingPosition(state.home))
    end)

    ---@param state DigChunkState
    resumable:setFinish(function(state)
        task.progress = 100
        self:updateTask()
        service.markChunkDugOut(task.chunkX, task.chunkZ)
        TurtleApi.navigate(state.home)
        TurtleApi.face(state.facing)
        TurtleApi.dumpAllToStorage({[ItemApi.diskDrive] = 1})
    end)

    resumable:run()
end

return DigChunkWorker
