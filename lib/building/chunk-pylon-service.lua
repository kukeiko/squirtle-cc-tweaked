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
---@param storageY integer
function ChunkPylonService.create(chunkX, chunkZ, storageY)
    ChunkPylonRepository.create(chunkX, chunkZ, storageY)
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

return ChunkPylonService
