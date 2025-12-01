---@class ChunkPylonService : Service
local ChunkPylonService = {name = "chunk-pylon"}

---@param x integer
---@param y integer
---@param reserveFor string
---@return true
function ChunkPylonService.reserveChunk(x, y, reserveFor)
    error("not implemented")
end

---@param x integer
---@param y integer
function ChunkPylonService.markChunkComplete(x, y)
    error("not implemented")
end

---@param x integer
---@param y integer
---@return boolean
function ChunkPylonService.isStorageBuilt(x, y)
    error("not implemented")
end

return ChunkPylonService
