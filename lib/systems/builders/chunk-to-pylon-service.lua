---@class ChunkToPylonService : Service
local ChunkToPylonService = {name = "chunk-to-pylon"}

---@param x integer
---@param y integer
---@param reserveFor string
---@return true
function ChunkToPylonService.reserveChunk(x, y, reserveFor)
    error("not implemented")
end

---@param x integer
---@param y integer
function ChunkToPylonService.markChunkComplete(x, y)
    error("not implemented")
end

---@param x integer
---@param y integer
---@return boolean
function ChunkToPylonService.isStorageBuilt(x, y)
    error("not implemented")
end

return ChunkToPylonService
