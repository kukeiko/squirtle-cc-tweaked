local EventLoop = require "lib.tools.event-loop"
local TaskWorker = require "lib.system.task-worker"
local TurtleApi = require "lib.turtle.turtle-api"
local ItemApi = require "lib.inventory.item-api"

---@class TurtleTaskWorker : TaskWorker 
local TurtleTaskWorker = {}
setmetatable(TurtleTaskWorker, {__index = TaskWorker})

---@param task Task
---@param taskService TaskService | RpcClient
---@return TurtleTaskWorker
function TurtleTaskWorker.new(task, taskService)
    local instance = TaskWorker.new(task, taskService) --[[@as TurtleTaskWorker]]
    setmetatable(instance, {__index = TurtleTaskWorker})

    return instance
end

---@param level integer
function TurtleTaskWorker:requireFuel(level)
    local openFuel = TurtleApi.getOpenFuel(level)

    if openFuel == 0 then
        return
    end

    TurtleApi.connectToStorage(function(inventory)
        local requiredCharcoal = ItemApi.getRequiredRefuelCount(ItemApi.charcoal, openFuel)

        EventLoop.run(function()
            TurtleApi.refuelTo(level)
        end, function()
            self:provideItems({[ItemApi.charcoal] = requiredCharcoal}, {inventory}, "charcoal")
        end)
    end)
end

---@param quantity integer
function TurtleTaskWorker:requireShulkers(quantity)
    TurtleApi.connectToStorage(function(inventory)
        self:provideItems({[ItemApi.shulkerBox] = quantity}, {inventory}, "shulkers", true)
        TurtleApi.condense()
    end)
end

---@param items ItemStock
---@param label string
function TurtleTaskWorker:requireItems(items, label)
    TurtleApi.connectToStorage(function(inventory)
        EventLoop.run(function()
            TurtleApi.requireItems(items, true)
        end, function()
            self:provideItems(items, {inventory}, label, true)
            TurtleApi.condense()
        end)
    end)
end

return TurtleTaskWorker
