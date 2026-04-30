local Utils = require "lib.tools.utils"
local ChunkPylonRepository = require "lib.database.chunk-pylon-repository"
local TaskService = require "lib.system.task-service"

---@class ChunkPylonService : Service
local ChunkPylonService = {name = "chunk-pylon"}

---@param chunkX integer
---@param chunkZ integer
---@param taskType TaskType
---@return boolean
local function hasChunkTask(chunkX, chunkZ, taskType)
    local chunkTasks = TaskService.getAcceptedTasksByType(taskType) --[[@as table<integer, ChunkTaskBase>]]
    local task = Utils.find(chunkTasks, function(item)
        return item.chunkX == chunkX and item.chunkZ == chunkZ
    end)

    return task ~= nil
end

---@return ChunkPylon[]
function ChunkPylonService.getAll()
    return ChunkPylonRepository.getAll()
end

---@param chunkX integer
---@param chunkZ integer
---@return ChunkPylon?
function ChunkPylonService.tryGet(chunkX, chunkZ)
    local chunkPylon = ChunkPylonRepository.find(chunkX, chunkZ)

    if not chunkPylon then
        return nil
    end

    chunkPylon.isBuildingStorage = hasChunkTask(chunkX, chunkZ, "build-chunk-storage")
    chunkPylon.isDiggingChunk = hasChunkTask(chunkX, chunkZ, "dig-chunk")
    chunkPylon.isRebuildingChunk = hasChunkTask(chunkX, chunkZ, "build-chunk-pylon")

    return chunkPylon
end

---@param chunkX integer
---@param chunkZ integer
---@return ChunkPylon
function ChunkPylonService.get(chunkX, chunkZ)
    local chunkPylon = ChunkPylonService.tryGet(chunkX, chunkZ)

    if not chunkPylon then
        error(string.format("chunk pylon %d/%d not found", chunkX, chunkZ))
    end

    return chunkPylon
end

---@param chunkX integer
---@param chunkZ integer
---@param storageY integer
function ChunkPylonService.create(chunkX, chunkZ, storageY)
    ChunkPylonRepository.create(chunkX, chunkZ, storageY)
end

---@param chunkX integer
---@param chunkZ integer
---@return boolean
function ChunkPylonService.canUpdateStorageY(chunkX, chunkZ)
    local chunkPylon = ChunkPylonService.get(chunkX, chunkZ)
    local storageBusy = chunkPylon.isBuildingStorage or chunkPylon.isStorageBuilt
    local diggingBusy = chunkPylon.isDiggingChunk or chunkPylon.isChunkDugOut
    local pylonBusy = chunkPylon.isRebuildingChunk or chunkPylon.isPylonBuilt
    local removalBusy = chunkPylon.isRemovingStorage

    return not storageBusy and not diggingBusy and not pylonBusy and not removalBusy
end

---@param chunkX integer
---@param chunkZ integer
---@param storageY integer
function ChunkPylonService.updateStorageY(chunkX, chunkZ, storageY)
    if not ChunkPylonService.canUpdateStorageY(chunkX, chunkZ) then
        error(string.format("not allowed to update storageY of chunk pylon %d/%d", chunkX, chunkZ))
    end

    local chunkPylon = ChunkPylonRepository.get(chunkX, chunkZ)
    chunkPylon.storageY = storageY
    ChunkPylonRepository.save(chunkPylon)

    return chunkPylon
end

---@param issuedBy string
---@param chunkX integer
---@param chunkZ integer
function ChunkPylonService.buildStorage(issuedBy, chunkX, chunkZ)
    local chunkPylon = ChunkPylonRepository.get(chunkX, chunkZ)

    TaskService.buildChunkStorage({
        chunkX = chunkPylon.chunkX,
        chunkZ = chunkPylon.chunkZ,
        storageY = chunkPylon.storageY,
        issuedBy = issuedBy,
        label = chunkPylon.id,
        autoDelete = true,
        skipAwait = true
    })
end

---@param issuedBy string
---@param chunkX integer
---@param chunkZ integer
function ChunkPylonService.digChunk(issuedBy, chunkX, chunkZ)
    local chunkPylon = ChunkPylonRepository.get(chunkX, chunkZ)

    TaskService.digChunk({
        chunkX = chunkPylon.chunkX,
        chunkZ = chunkPylon.chunkZ,
        storageY = chunkPylon.storageY,
        issuedBy = issuedBy,
        label = chunkPylon.id,
        autoDelete = true,
        skipAwait = true
    })
end

---@param issuedBy string
---@param chunkX integer
---@param chunkZ integer
function ChunkPylonService.buildPylon(issuedBy, chunkX, chunkZ)
    local chunkPylon = ChunkPylonRepository.get(chunkX, chunkZ)

    TaskService.buildChunkPylon({
        issuedBy = issuedBy,
        chunkX = chunkPylon.chunkX,
        chunkZ = chunkPylon.chunkZ,
        storageY = chunkPylon.storageY,
        label = chunkPylon.id,
        autoDelete = true,
        skipAwait = true
    })
end

---@param chunkX integer
---@param chunkZ integer
function ChunkPylonService.markStorageBuilt(chunkX, chunkZ)
    local chunkPylon = ChunkPylonRepository.get(chunkX, chunkZ)
    chunkPylon.isStorageBuilt = true
    ChunkPylonRepository.save(chunkPylon)
end

---@param chunkX integer
---@param chunkZ integer
function ChunkPylonService.markChunkDugOut(chunkX, chunkZ)
    local chunkPylon = ChunkPylonRepository.get(chunkX, chunkZ)
    chunkPylon.isChunkDugOut = true
    ChunkPylonRepository.save(chunkPylon)
end

---@param chunkX integer
---@param chunkZ integer
function ChunkPylonService.markPylonBuilt(chunkX, chunkZ)
    local chunkPylon = ChunkPylonRepository.get(chunkX, chunkZ)
    chunkPylon.isPylonBuilt = true
    ChunkPylonRepository.save(chunkPylon)
end

---@param chunkX integer
---@param chunkZ integer
---@param y integer
function ChunkPylonService.markLayerDugOut(chunkX, chunkZ, y)
    local chunkPylon = ChunkPylonRepository.get(chunkX, chunkZ)
    chunkPylon.lastDugY = y
    ChunkPylonRepository.save(chunkPylon)
end

---@param chunkX integer
---@param chunkZ integer
---@param y integer
function ChunkPylonService.markLayerBuilt(chunkX, chunkZ, y)
    local chunkPylon = ChunkPylonRepository.get(chunkX, chunkZ)
    chunkPylon.lastBuiltY = y
    ChunkPylonRepository.save(chunkPylon)
end

return ChunkPylonService
