local Utils = require "lib.tools.utils"
local ItemStock = require "lib.models.item-stock"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local InventoryApi = require "lib.apis.inventory.inventory-api"
local DatabaseApi = require "lib.apis.database.database-api"

---@class TaskBufferApi
local TaskBufferApi = {}

---@type table<string, true>
local locks = {}

---@param bufferId integer
---@return fun() : nil
local function lock(bufferId)
    while locks[bufferId] do
        os.sleep(1)
    end

    locks[bufferId] = true

    return function()
        locks[bufferId] = nil
    end
end

---@return table<string, unknown>
local function getAllocatedInventories()
    ---@type table<string, unknown>
    local allocatedInventories = {}
    local allocatedBuffers = DatabaseApi.getAllocatedBuffers()

    for _, allocatedBuffer in pairs(allocatedBuffers) do
        for _, name in pairs(allocatedBuffer.inventories) do
            allocatedInventories[name] = true
        end
    end

    return allocatedInventories
end

---@param slotCount integer
local function getAllocationCandidates(slotCount)
    local buffers = InventoryApi.getByType("buffer")
    local alreadyAllocated = getAllocatedInventories()
    ---@type string[]
    local candidates = {}
    local openSlots = slotCount

    for _, buffer in pairs(buffers) do
        if not alreadyAllocated[buffer] then
            table.insert(candidates, buffer)
            openSlots = openSlots - InventoryApi.getSlotCount({buffer}, "buffer")

            if openSlots <= 0 then
                break
            end
        end
    end

    if openSlots > 0 then
        error(string.format("no more buffer available to fulfill %d slots (%d more required)", slotCount, openSlots))
    end

    return candidates
end

---@param bufferId integer
local function compact(bufferId)
    local buffer = DatabaseApi.getAllocatedBuffer(bufferId)

    if #buffer.inventories == 1 then
        return
    end

    for i = #buffer.inventories, 1, -1 do
        local from = buffer.inventories[i]
        local to = {}

        for j = 1, i - 1 do
            table.insert(to, buffer.inventories[j])
        end

        if not InventoryApi.empty({from}, "buffer", to, "buffer", {toSequential = true}) then
            return
        end
    end
end

---@param bufferId integer
---@param targetSlotCount integer
local function resize(bufferId, targetSlotCount)
    local buffer = DatabaseApi.getAllocatedBuffer(bufferId)
    local currentSlotCount = InventoryApi.getSlotCount(buffer.inventories, "buffer")

    if targetSlotCount < currentSlotCount then
        compact(bufferId)
        local openSlots = targetSlotCount
        ---@type string[]
        local resizedInventories = {}

        for i = 1, #buffer.inventories do
            local inventory = buffer.inventories[i]
            table.insert(resizedInventories, inventory)
            openSlots = openSlots - InventoryApi.getSlotCount({inventory}, "buffer")

            if openSlots <= 0 then
                break
            end
        end

        -- [todo] what if the "removed" inventories still contain items?
        buffer.inventories = resizedInventories
    else
        local newlyAllocated = getAllocationCandidates(targetSlotCount - currentSlotCount)

        for _, inventory in pairs(newlyAllocated) do
            table.insert(buffer.inventories, inventory)
        end
    end

    DatabaseApi.updateAllocatedBuffer(buffer)
end

---@param bufferId integer
---@return AllocatedBuffer
function TaskBufferApi.getBuffer(bufferId)
    return DatabaseApi.getAllocatedBuffer(bufferId)
end

---@param taskId integer
---@param slotCount? integer
---@return integer
function TaskBufferApi.allocateTaskBuffer(taskId, slotCount)
    slotCount = slotCount or 1
    local allocatedBuffer = DatabaseApi.findAllocatedBuffer(taskId)

    if allocatedBuffer then
        -- [todo] check if slotCount can still be fulfilled
        return allocatedBuffer.id
    end

    local newlyAllocated = getAllocationCandidates(slotCount)
    allocatedBuffer = DatabaseApi.createAllocatedBuffer(newlyAllocated, taskId)

    return allocatedBuffer.id
end

---@param bufferId integer
---@param targetSlotCount integer
function TaskBufferApi.resize(bufferId, targetSlotCount)
    local unlock = lock(bufferId)
    resize(bufferId, targetSlotCount)
    unlock()
end

---@param bufferId integer
---@param additionalStock ItemStock
function TaskBufferApi.resizeByStock(bufferId, additionalStock)
    local unlock = lock(bufferId)
    local bufferStock = TaskBufferApi.getBufferStock(bufferId)
    local totalStock = ItemStock.merge({bufferStock, additionalStock})
    local requiredSlots = InventoryPeripheral.getRequiredSlotCount(totalStock)
    resize(bufferId, requiredSlots)
    unlock()
end

---@param bufferId integer
function TaskBufferApi.freeBuffer(bufferId)
    DatabaseApi.deleteAllocatedBuffer(bufferId)
end

---@param bufferId integer
---@return string[]
function TaskBufferApi.resolveBuffer(bufferId)
    return DatabaseApi.getAllocatedBuffer(bufferId).inventories
end

---@param bufferId integer
---@return ItemStock
function TaskBufferApi.getBufferStock(bufferId)
    local buffer = DatabaseApi.getAllocatedBuffer(bufferId)

    return InventoryApi.getStock(buffer.inventories, "buffer")
end

return TaskBufferApi
