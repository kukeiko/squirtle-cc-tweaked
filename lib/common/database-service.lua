local Utils = require "lib.common.utils"
local TaskRepository = require "lib.common.database.task-repository"

---@class DatabaseService : Service
local DatabaseService = {name = "database", folder = "data"}

local entityTypes = {
    allocatedBuffers = "allocated-buffers",
    craftingRecipes = "crafting-recipes",
    subwayStations = "subway-stations",
    squirtleResumables = "squirtle-resumables",
    squirtleDiskState = "squirtle-disk-state",
    tasks = "tasks"
}

---@param entity string
local function getPath(entity)
    return DatabaseService.folder .. "/" .. entity .. ".json"
end

---@return string
local function getIdsPath()
    return DatabaseService.folder .. "/ids.json"
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
function DatabaseService.getSubwayStations()
    return readEntities(entityTypes.subwayStations)
end

---@param stations SubwayStation[]
function DatabaseService.setSubwayStations(stations)
    -- [todo] hack - should be fixed with newer cc:tweaked version
    for _, station in pairs(stations) do
        if #station.tracks == 0 then
            station.tracks = {}
        end
    end

    writeEntities(entityTypes.subwayStations, stations)
end

---@return CraftingRecipes
function DatabaseService.getCraftingRecipes()
    ---@type CraftingRecipe[]
    local recipes = readEntities(entityTypes.craftingRecipes)

    return Utils.toMap(recipes, function(item)
        return item.item
    end)
end

---@param recipes CraftingRecipes
function DatabaseService.setCraftingRecipes(recipes)
    writeEntities(entityTypes.craftingRecipes, Utils.toList(recipes))
end

---@param item string
---@return CraftingRecipe?
function DatabaseService.getCraftingRecipe(item)
    local recipe = Utils.find(DatabaseService.getCraftingRecipes(), function(recipe)
        return recipe.item == item
    end)

    return recipe
end

---@param task Task
---@return Task
function DatabaseService.createTask(task)
    return TaskRepository.createTask(task)
end

---@return Task[]
function DatabaseService.getTasks()
    return TaskRepository.getTasks()
end

---@param id integer
---@return Task
function DatabaseService.getTask(id)
    return TaskRepository.getTask(id)
end

---@param id integer
---@param status TaskStatus
function DatabaseService.completeTask(id, status)
    TaskRepository.completeTask(id, status)
end

---@param task Task
function DatabaseService.updateTask(task)
    TaskRepository.updateTask(task)
end

---@param id integer
function DatabaseService.deleteTask(id)
    TaskRepository.deleteTask(id)
end

---@param type TaskType
---@return Task?
function DatabaseService.getIssuedTask(type)
    return Utils.find(DatabaseService.getTasks(), function(task)
        return task.type == type and task.status == "issued"
    end)
end

---@param acceptedBy string
---@param type TaskType
---@return Task?
function DatabaseService.getAcceptedTask(acceptedBy, type)
    return Utils.find(DatabaseService.getTasks(), function(task)
        return task.status == "accepted" and task.type == type and task.acceptedBy == acceptedBy
    end)
end

---@param taskId integer
---@param inventories string[]
function DatabaseService.createAllocatedBuffer(inventories, taskId)
    local entityType = entityTypes.allocatedBuffers
    ---@type AllocatedBuffer
    local allocatedBuffer = {id = nextId(entityType), inventories = inventories, taskId = taskId}
    pushEntity(entityType, allocatedBuffer)

    return allocatedBuffer
end

---@return AllocatedBuffer[]
function DatabaseService.getAllocatedBuffers()
    return readEntities(entityTypes.allocatedBuffers)
end

---@param id integer
---@return AllocatedBuffer
function DatabaseService.getAllocatedBuffer(id)
    local buffer = Utils.find(DatabaseService.getAllocatedBuffers(), function(candidate)
        return candidate.id == id
    end)

    if not buffer then
        error(string.format("allocated buffer %d doesn't exist", id))
    end

    return buffer
end

---@param taskId integer
---@return AllocatedBuffer?
function DatabaseService.findAllocatedBuffer(taskId)
    return Utils.find(DatabaseService.getAllocatedBuffers(), function(candidate)
        return candidate.taskId == taskId
    end)
end

---@param bufferId integer
function DatabaseService.deleteAllocatedBuffer(bufferId)
    local buffers = Utils.filter(DatabaseService.getAllocatedBuffers(), function(item)
        return item.id ~= bufferId
    end)

    writeEntities(entityTypes.allocatedBuffers, buffers)
end

---@return SquirtleDiskState
function DatabaseService.getSquirtleDiskState()
    ---@type SquirtleDiskState
    local state = readEntities(entityTypes.squirtleDiskState)
    state.cleanupSides = state.cleanupSides or {}
    state.diskDriveSides = state.diskDriveSides or {}

    return state
end

---@param state SquirtleDiskState
function DatabaseService.saveSquirtleDiskState(state)
    writeEntities(entityTypes.squirtleDiskState, state)
end

---@return SquirtleResumable[]
function DatabaseService.getSquirtleResumables()
    return readEntities(entityTypes.squirtleResumables)
end

---@param name string
---@return SquirtleResumable?
function DatabaseService.findSquirtleResumable(name)
    return Utils.find(DatabaseService.getSquirtleResumables(), function(item)
        return item.name == name
    end)
end

---@param name string
---@return SquirtleResumable
function DatabaseService.getSquirtleResumable(name)
    local resumable = DatabaseService.findSquirtleResumable(name)

    if not resumable then
        error(string.format("squirtle resumable %s doesn't exist", name))
    end

    return resumable
end

---@param resumable SquirtleResumable
---@return SquirtleResumable
function DatabaseService.createSquirtleResumable(resumable)
    pushEntity(entityTypes.squirtleResumables, resumable)

    return resumable
end

---@param name string
function DatabaseService.deleteSquirtleResumable(name)
    local resumables = Utils.filter(DatabaseService.getSquirtleResumables(), function(item)
        return item.name ~= name
    end)

    writeEntities(entityTypes.squirtleResumables, resumables)
end

return DatabaseService
