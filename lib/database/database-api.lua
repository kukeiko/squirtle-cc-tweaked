local Utils = require "lib.tools.utils"
local CraftingRecipeRepository = require "lib.database.crafting-recipe-repository"

---@class DatabaseApi
local DatabaseApi = {folder = "data"}

local entityTypes = {subwayStations = "subway-stations", turtleResumables = "turtle-resumables", turtleDiskState = "turtle-disk-state"}

---@param entity string
local function getPath(entity)
    return DatabaseApi.folder .. "/" .. entity .. ".json"
end

---@param entity string
---@return table
local function readEntities(entity)
    return Utils.readJson(getPath(entity)) or {}
end

---@param entity string
---@param entities table
local function writeEntities(entity, entities)
    Utils.writeJson(getPath(entity), entities)
end

---@param entityType string
---@param entity table
local function pushEntity(entityType, entity)
    local entities = readEntities(entityType)
    table.insert(entities, entity)
    writeEntities(entityType, entities)
end

---@return SubwayStation[]
function DatabaseApi.getSubwayStations()
    return readEntities(entityTypes.subwayStations)
end

---@param stations SubwayStation[]
function DatabaseApi.setSubwayStations(stations)
    -- [todo] hack - should be fixed with newer cc:tweaked version
    for _, station in pairs(stations) do
        if #station.tracks == 0 then
            station.tracks = {}
        end
    end

    writeEntities(entityTypes.subwayStations, stations)
end

---@return CraftingRecipes
function DatabaseApi.getCraftingRecipes()
    return CraftingRecipeRepository.getAll()
end

---@param item string
---@return CraftingRecipe?
function DatabaseApi.getCraftingRecipe(item)
    return CraftingRecipeRepository.find(item)
end

---@param recipe CraftingRecipe
function DatabaseApi.saveCraftingRecipe(recipe)
    CraftingRecipeRepository.save(recipe)
end

---@return TurtleDiskState
function DatabaseApi.getTurtleDiskState()
    ---@type TurtleDiskState
    local state = readEntities(entityTypes.turtleDiskState) or {}
    state.cleanupSides = state.cleanupSides or {}
    state.diskDriveSides = state.diskDriveSides or {}
    state.shulkerSides = state.shulkerSides or {}

    return state
end

---@param state TurtleDiskState
function DatabaseApi.saveTurtleDiskState(state)
    writeEntities(entityTypes.turtleDiskState, state)
end

---@return TurtleResumable[]
function DatabaseApi.getTurtleResumables()
    return readEntities(entityTypes.turtleResumables)
end

---@param name string
---@return TurtleResumable?
function DatabaseApi.findTurtleResumable(name)
    return Utils.find(DatabaseApi.getTurtleResumables(), function(item)
        return item.name == name
    end)
end

---@param name string
---@return TurtleResumable
function DatabaseApi.getTurtleResumable(name)
    local resumable = DatabaseApi.findTurtleResumable(name)

    if not resumable then
        error(string.format("TurtleResumable %s doesn't exist", name))
    end

    return resumable
end

---@param resumable TurtleResumable
---@return TurtleResumable
function DatabaseApi.createTurtleResumable(resumable)
    pushEntity(entityTypes.turtleResumables, resumable)

    return resumable
end

---@param resumable TurtleResumable
function DatabaseApi.updateTurtleResumable(resumable)
    local resumables = DatabaseApi.getTurtleResumables()
    local index = Utils.findIndex(resumables, function(candidate)
        return candidate.name == resumable.name
    end)

    if not index then
        error(string.format("can't update turtle resumable: %s doesn't exist", resumable.name))
    end

    resumables[index] = resumable
    writeEntities(entityTypes.turtleResumables, resumables)
end

---@param name string
function DatabaseApi.deleteTurtleResumable(name)
    local resumables = Utils.filter(DatabaseApi.getTurtleResumables(), function(item)
        return item.name ~= name
    end)

    writeEntities(entityTypes.turtleResumables, resumables)
end

return DatabaseApi
