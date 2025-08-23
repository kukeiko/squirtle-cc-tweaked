local Utils = require "lib.tools.utils"
local TaskRepository = require "lib.database.task-repository"

---@class DatabaseApi
local DatabaseApi = {folder = "data"}

local entityTypes = {
    allocatedBuffers = "allocated-buffers",
    craftingRecipes = "crafting-recipes",
    subwayStations = "subway-stations",
    turtleResumables = "turtle-resumables",
    turtleDiskState = "turtle-disk-state",
    tasks = "tasks"
}

---@param entity string
local function getPath(entity)
    return DatabaseApi.folder .. "/" .. entity .. ".json"
end

---@return string
local function getIdsPath()
    return DatabaseApi.folder .. "/ids.json"
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

---@param entity string
---@return integer
local function nextId(entity)
    local ids = Utils.readJson(getIdsPath()) or {}

    if not ids[entity] then
        ids[entity] = 0
    end

    ids[entity] = ids[entity] + 1
    Utils.writeJson(getIdsPath(), ids)

    return ids[entity]
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
    ---@type CraftingRecipe[]
    local recipes = readEntities(entityTypes.craftingRecipes)

    return Utils.toMap(recipes, function(item)
        return item.item
    end)
end

---@param recipes CraftingRecipes
function DatabaseApi.setCraftingRecipes(recipes)
    writeEntities(entityTypes.craftingRecipes, Utils.toList(recipes))
end

---@param item string
---@return CraftingRecipe?
function DatabaseApi.getCraftingRecipe(item)
    local recipe = Utils.find(DatabaseApi.getCraftingRecipes(), function(recipe)
        return recipe.item == item
    end)

    return recipe
end

---@param recipe CraftingRecipe
function DatabaseApi.saveCraftingRecipe(recipe)
    local recipes = DatabaseApi.getCraftingRecipes()
    recipes[recipe.item] = recipe
    DatabaseApi.setCraftingRecipes(recipes)
end

---@param task Task
---@return Task
function DatabaseApi.createTask(task)
    return TaskRepository.createTask(task)
end

---@return Task[]
function DatabaseApi.getTasks()
    return TaskRepository.getTasks()
end

---@param id integer
---@return Task
function DatabaseApi.getTask(id)
    return TaskRepository.getTask(id)
end

---@param id integer
---@param status TaskStatus
function DatabaseApi.completeTask(id, status)
    TaskRepository.completeTask(id, status)
end

---@param task Task
function DatabaseApi.updateTask(task)
    TaskRepository.updateTask(task)
end

---@param id integer
function DatabaseApi.deleteTask(id)
    TaskRepository.deleteTask(id)
end

---@param type TaskType
---@return Task?
function DatabaseApi.getIssuedTask(type)
    return Utils.find(DatabaseApi.getTasks(), function(task)
        return task.type == type and task.status == "issued"
    end)
end

---@param acceptedBy string
---@param type TaskType
---@return Task?
function DatabaseApi.getAcceptedTask(acceptedBy, type)
    return Utils.find(DatabaseApi.getTasks(), function(task)
        return task.status == "accepted" and task.type == type and task.acceptedBy == acceptedBy
    end)
end

---@param taskId integer
---@param inventories string[]
function DatabaseApi.createAllocatedBuffer(inventories, taskId)
    local entityType = entityTypes.allocatedBuffers
    ---@type AllocatedBuffer
    local allocatedBuffer = {id = nextId(entityType), inventories = inventories, taskId = taskId}
    pushEntity(entityType, allocatedBuffer)

    return allocatedBuffer
end

---@return AllocatedBuffer[]
function DatabaseApi.getAllocatedBuffers()
    return readEntities(entityTypes.allocatedBuffers)
end

---@param id integer
---@return AllocatedBuffer
function DatabaseApi.getAllocatedBuffer(id)
    local buffer = Utils.find(DatabaseApi.getAllocatedBuffers(), function(candidate)
        return candidate.id == id
    end)

    if not buffer then
        error(string.format("allocated buffer %d doesn't exist", id))
    end

    return buffer
end

---@param taskId integer
---@return AllocatedBuffer?
function DatabaseApi.findAllocatedBuffer(taskId)
    return Utils.find(DatabaseApi.getAllocatedBuffers(), function(candidate)
        return candidate.taskId == taskId
    end)
end

---@param buffer AllocatedBuffer
function DatabaseApi.updateAllocatedBuffer(buffer)
    local buffers = DatabaseApi.getAllocatedBuffers()
    local index = Utils.findIndex(buffers, function(candidate)
        return candidate.id == buffer.id
    end)

    if not index then
        error(string.format("can't update buffer: buffer %d doesn't exist", buffer.id))
    end

    buffers[index] = buffer
    writeEntities(entityTypes.allocatedBuffers, buffers)
end

---@param bufferId integer
function DatabaseApi.deleteAllocatedBuffer(bufferId)
    local buffers = Utils.filter(DatabaseApi.getAllocatedBuffers(), function(item)
        return item.id ~= bufferId
    end)

    writeEntities(entityTypes.allocatedBuffers, buffers)
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
