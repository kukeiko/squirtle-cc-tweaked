local Utils = require "utils"

---@class DatabaseService : Service
local DatabaseService = {name = "database", folder = "data"}

---@param entity string
local function getPath(entity)
    return DatabaseService.folder .. "/" .. entity .. ".json"
end

---@param entity string
---@return table[]
local function readEntities(entity)
    return Utils.readJson(getPath(entity)) or {}
end

---@param entity string
---@param entities table[]
local function writeEntities(entity, entities)
    Utils.writeJson(getPath(entity), entities)
end

---@return SubwayStation[]
function DatabaseService.getSubwayStations()
    return readEntities("subway-stations")
end

---@param stations SubwayStation[]
function DatabaseService.setSubwayStations(stations)
    writeEntities("subway-stations", stations)
end

---@param stationId? string
---@return SubwayTrack[]
function DatabaseService.getSubwayTracks(stationId)
    ---@type SubwayTrack[]
    local tracks = readEntities("subway-tracks")

    if stationId == nil then
        return tracks
    end

    return Utils.filter(tracks, function(item)
        return item.stationId == stationId
    end)
end

---@param tracks SubwayTrack[]
function DatabaseService.setSubwayTracks(tracks)
    writeEntities("subway-tracks", tracks)
end

---@param stationId string
---@param signal integer
---@return SubwayTrack?
function DatabaseService.getSubwayTrack(stationId, signal)
    local track = Utils.find(DatabaseService.getSubwayTracks(stationId), function(item)
        return item.signal == signal
    end)

    return track
end

---@return CraftingRecipe[]
function DatabaseService.getCraftingRecipes()
    return readEntities("crafting-recipes")
end

---@param item string
---@return CraftingRecipe?
function DatabaseService.getCraftingRecipe(item)
    local recipe = Utils.find(DatabaseService.getCraftingRecipes(), function(recipe)
        return recipe.item == item
    end)

    return recipe
end

return DatabaseService
