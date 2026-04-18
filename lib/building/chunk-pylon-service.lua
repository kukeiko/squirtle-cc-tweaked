local ChunkPylonRepository = require "lib.database.chunk-pylon-repository"
local TaskService = require "lib.system.task-service"

---@class ChunkPylonService : Service
local ChunkPylonService = {name = "chunk-pylon"}

---@return ChunkPylon[]
function ChunkPylonService.getAll()
    return ChunkPylonRepository.getAll()
end

---@param chunkX integer
---@param chunkZ integer
---@return ChunkPylon?
function ChunkPylonService.tryGet(chunkX, chunkZ)
    return ChunkPylonRepository.find(chunkX, chunkZ)
end

---@param chunkX integer
---@param chunkZ integer
---@param storageY integer
function ChunkPylonService.create(chunkX, chunkZ, storageY)
    ChunkPylonRepository.create(chunkX, chunkZ, storageY)
end

---@param chunkX integer
---@param chunkZ integer
function ChunkPylonService.buildStorage(chunkX, chunkZ)
    local chunkPylon = ChunkPylonRepository.get(chunkX, chunkZ)

    TaskService.buildChunkStorage({
        chunkX = chunkPylon.chunkX,
        chunkZ = chunkPylon.chunkZ,
        y = chunkPylon.storageY,
        issuedBy = os.getComputerLabel(),
        label = chunkPylon.id
    })
end

---@param chunkX integer
---@param chunkZ integer
function ChunkPylonService.markStorageBuilt(chunkX, chunkZ)
    local chunkPylon = ChunkPylonRepository.get(chunkX, chunkZ)
    chunkPylon.isStorageBuilt = true
    ChunkPylonRepository.save(chunkPylon)
end

return ChunkPylonService
