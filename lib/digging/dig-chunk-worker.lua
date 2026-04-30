local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
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
    -- [todo] ❌ record lastDugY and use it for resuming
    local firstLayerY = task.storageY - 1
    local numShulkers = 4
    local layersPerIteration = math.floor((numShulkers * 27 * 64) / (16 * 16) * 0.8)
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

            -- move to start position of current iteration
            TurtleApi.move("down")
            TurtleApi.turn("right")
            TurtleApi.move("forward", 8)
            TurtleApi.turn("right")
            TurtleApi.move("forward", 8)
            TurtleApi.turn("back")
            TurtleApi.move("down", layersPerIteration * (i - 1))

            -- dig out
            EventLoop.waitForAny(function()
                TurtleApi.digArea(16, -16, digHeight, TurtleApi.getPosition(), TurtleApi.getFacing())
            end, function()
                if not TurtleApi.isSimulating() then
                    while true do
                        os.sleep(60)
                        local deltaY = firstLayerY - TurtleApi.getPosition().y
                        task.progress = math.floor((deltaY / totalDigHeight) * 100)
                        self:updateTask()
                    end
                end
            end)

            -- move back to storage
            TurtleApi.move("up", layersPerIteration * (i - 1))
            TurtleApi.move("forward", 8)
            TurtleApi.turn("left")
            TurtleApi.move("forward", 8)
            TurtleApi.turn("right")
            TurtleApi.move("up")
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
        local service = Rpc.nearest(ChunkPylonService)
        service.markChunkDugOut(task.chunkX, task.chunkZ)
        TurtleApi.navigate(state.home)
        TurtleApi.face(state.facing)
        TurtleApi.dumpAllToStorage({[ItemApi.diskDrive] = 1})
    end)

    resumable:run()
end

return DigChunkWorker
