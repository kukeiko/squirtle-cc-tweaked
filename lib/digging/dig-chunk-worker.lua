local Cardinal = require "lib.common.cardinal"
local ItemStock = require "lib.inventory.item-stock"
local ItemApi = require "lib.inventory.item-api"
local TurtleTaskWorker = require "lib.system.turtle-task-worker"
local TurtleApi = require "lib.turtle.turtle-api"
local Resumable = require "lib.turtle.resumable"

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
    local firstLayerY = task.y - 1
    local numShulkers = 8 -- [todo] ❓reduce to 4 instead?
    local layersPerIteration = math.floor((numShulkers * 27 * 64) / (16 * 16) * 0.8)
    local height = firstLayerY + 60
    local iterations = math.ceil(height / layersPerIteration)

    resumable:setStart(function()
        self:requireFuel(TurtleApi.getFiniteFuelLimit())
        self:requireShulkers(numShulkers)
        TurtleApi.locate()
        TurtleApi.orientate("disk-drive")

        ---@class DigChunkState
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

    for i = 1, iterations do
        ---@param state DigChunkState
        resumable:addSimulatableMain(string.format("dig-%d", i), function(state)
            local targetLayerY = firstLayerY - ((i - 1) * layersPerIteration)
            local digHeight = -layersPerIteration

            if targetLayerY + digHeight <= -60 then
                digHeight = -60 - targetLayerY
            end

            -- move to start position of current iteration
            TurtleApi.move("down")
            TurtleApi.turn("right")
            TurtleApi.move("forward", 8)
            TurtleApi.turn("right")
            TurtleApi.move("forward", 8)
            TurtleApi.turn("back")
            TurtleApi.move("down", layersPerIteration * (i - 1))
            -- dig out
            TurtleApi.digArea(16, -16, digHeight, TurtleApi.getPosition(), TurtleApi.getFacing())
            -- move back to storage
            TurtleApi.move("up", layersPerIteration * (i - 1))
            TurtleApi.move("forward", 8)
            TurtleApi.turn("left")
            TurtleApi.move("forward", 8)
            TurtleApi.turn("right")
            TurtleApi.move("up")
        end)

        resumable:addMain(string.format("dump-%d", i), function(state)
            -- [todo] ❌ dump items into storage
            local stock = TurtleApi.getStock(true)
            local dump = ItemStock.subtract(stock, {[ItemApi.shulkerBox] = stock[ItemApi.shulkerBox] or 0, [ItemApi.diskDrive] = 1})
            TurtleApi.dumpToStorage(dump)
        end)
    end

    ---@param state DigChunkState
    resumable:setFinish(function(state)
        TurtleApi.navigate(state.home)
        TurtleApi.face(state.facing)
        local stock = ItemStock.subtract(TurtleApi.getStock(true), {[ItemApi.diskDrive] = 1})
        TurtleApi.dumpToStorage(stock)
    end)

    resumable:run()
end

return DigChunkWorker
