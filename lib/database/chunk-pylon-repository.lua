local EntityRepository = require "lib.database.entity-repository"

---@param chunkX integer
---@param chunkZ integer
---@return string
local function toId(chunkX, chunkZ)
    return string.format("%d:%d", chunkX, chunkZ)
end

---@class ChunkPylon
---@field id string
---@field chunkX integer
---@field chunkZ integer
---@field storageY integer
---@field isStorageBuilt boolean
---@field isChunkDugOut boolean
---@field isPylonBuilt boolean
---@field isBuildingStorage boolean
---@field isRemovingStorage boolean
---@field isDiggingChunk boolean
---@field isRebuildingChunk boolean
---

---@class ChunkPylonRepository
local ChunkPylonRepository = {}
local repository = EntityRepository.new("chunk-pylons", false, "id")

---@return ChunkPylon[]
function ChunkPylonRepository.getAll()
    return repository:getAll()
end

---@param chunkX integer
---@param chunkZ integer
---@return ChunkPylon?
function ChunkPylonRepository.find(chunkX, chunkZ)
    return repository:findById(toId(chunkX, chunkZ))
end

---@param chunkX integer
---@param chunkZ integer
---@return ChunkPylon
function ChunkPylonRepository.get(chunkX, chunkZ)
    return repository:getById(toId(chunkX, chunkZ))
end

---@param chunkX integer
---@param chunkZ integer
---@param storageY integer
---@return ChunkPylon
function ChunkPylonRepository.create(chunkX, chunkZ, storageY)
    ---@type ChunkPylon
    local chunkPylon = {
        id = toId(chunkX, chunkZ),
        chunkX = chunkX,
        chunkZ = chunkZ,
        storageY = storageY,
        isBuildingStorage = false,
        isDiggingChunk = false,
        isRebuildingChunk = false,
        isRemovingStorage = false,
        isStorageBuilt = false,
        isChunkDugOut = false,
        isPylonBuilt = false
    }
    return repository:create(chunkPylon)
end

---@param chunkPylon ChunkPylon
function ChunkPylonRepository.save(chunkPylon)
    repository:save(chunkPylon)
end

return ChunkPylonRepository
