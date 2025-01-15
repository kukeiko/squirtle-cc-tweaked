local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local InventoryApi = require "lib.inventory.inventory-api" -- [todo] don't like that "common" imports from outside of itself
local DatabaseService = require "lib.common.database-service"

---@class TaskBufferService : Service
local TaskBufferService = {name = "task-buffer"}

---@return table<string, unknown>
local function getAllocatedInventories()
    local databaseService = Rpc.nearest(DatabaseService)
    ---@type table<string, unknown>
    local allocatedInventories = {}
    local allocatedBuffers = databaseService.getAllocatedBuffers()

    for _, allocatedBuffer in pairs(allocatedBuffers) do
        for _, name in pairs(allocatedBuffer.inventories) do
            allocatedInventories[name] = true
        end
    end

    return allocatedInventories
end

---@param taskId integer
---@param slotCount? integer
---@return integer
function TaskBufferService.allocateTaskBuffer(taskId, slotCount)
    local databaseService = Rpc.nearest(DatabaseService)
    -- [todo] calculation doesn't take into account multiple inventories
    slotCount = slotCount or 26 -- minus one to account for buffer name tag
    local allocatedBuffer = databaseService.findAllocatedBuffer(taskId)

    if allocatedBuffer then
        -- [todo] check if slotCount can still be fulfilled
        return allocatedBuffer.id
    end

    local buffers = InventoryApi.getByType("buffer")
    local alreadyAllocated = getAllocatedInventories()
    ---@type string[]
    local newlyAllocated = {}
    local openSlots = slotCount

    for _, buffer in pairs(buffers) do
        if not alreadyAllocated[buffer] then
            table.insert(newlyAllocated, buffer)
            openSlots = openSlots - InventoryApi.getSlotCount({buffer}, "buffer")

            if openSlots <= 0 then
                break
            end
        end
    end

    if openSlots > 0 then
        error(string.format("no more buffer available to fulfill %d slots (%d more required)", slotCount, openSlots))
    end

    allocatedBuffer = databaseService.createAllocatedBuffer(newlyAllocated, taskId)

    return allocatedBuffer.id
end

---@param bufferId integer
function TaskBufferService.freeBuffer(bufferId)
    local databaseService = Rpc.nearest(DatabaseService)
    databaseService.deleteAllocatedBuffer(bufferId)
end

---@param bufferId integer
function TaskBufferService.flushBuffer(bufferId)
    local storages = InventoryApi.getByType("storage")

    while not Utils.isEmpty(TaskBufferService.getBufferStock(bufferId)) do
        TaskBufferService.transferBufferStock(bufferId, storages, "input")
        os.sleep(1)
    end
end

---@param bufferId integer
---@param fromType? InventoryType
---@param fromTag? InventorySlotTag
---@param itemStock ItemStock
function TaskBufferService.transferStockToBuffer(bufferId, itemStock, fromType, fromTag)
    local databaseService = Rpc.nearest(DatabaseService)
    local buffer = databaseService.getAllocatedBuffer(bufferId)
    local storages = InventoryApi.getByType(fromType or "storage")
    InventoryApi.transferItems(storages, fromTag or "withdraw", buffer.inventories, "buffer", itemStock, {toSequential = true})
end

---@param bufferId integer
---@param from string
---@param fromTag InventorySlotTag
function TaskBufferService.transferInventoryStockToBuffer(bufferId, from, fromTag)
    local databaseService = Rpc.nearest(DatabaseService)
    local buffer = databaseService.getAllocatedBuffer(bufferId)
    local itemStock = InventoryApi.getStock({from}, fromTag)
    InventoryApi.transferItems({from}, fromTag, buffer.inventories, "buffer", itemStock, {toSequential = true})
end

---@param bufferId integer
---@return string[]
function TaskBufferService.getBufferNames(bufferId)
    local databaseService = Rpc.nearest(DatabaseService)
    return databaseService.getAllocatedBuffer(bufferId).inventories
end

---@param bufferId integer
---@return ItemStock
function TaskBufferService.getBufferStock(bufferId)
    local databaseService = Rpc.nearest(DatabaseService)
    local buffer = databaseService.getAllocatedBuffer(bufferId)

    return InventoryApi.getStock(buffer.inventories, "buffer")
end

---@param bufferId integer
---@param to string[]
---@param toTag InventorySlotTag
---@param stock? ItemStock
---@return ItemStock, ItemStock open
function TaskBufferService.transferBufferStock(bufferId, to, toTag, stock)
    local databaseService = Rpc.nearest(DatabaseService)
    local buffer = databaseService.getAllocatedBuffer(bufferId)
    local bufferStock = stock or TaskBufferService.getBufferStock(bufferId)
    -- [todo] setting "toSequential" to true as i expect to transfer between buffers most of the time.
    -- maybe it makes sense to have a dedicated "transferBufferStock" method for that instead?
    return InventoryApi.transferItems(buffer.inventories, "buffer", to, toTag, bufferStock, {fromSequential = true, toSequential = true})
end

return TaskBufferService
