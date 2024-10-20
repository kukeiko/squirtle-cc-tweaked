local Utils = require "lib.common.utils"

---@class DatabaseService : Service
local DatabaseService = {name = "database", folder = "data"}

local entityTypes = {
    allocatedBuffers = "allocated-buffers",
    subwayStations = "subway-stations",
    squirtleResumables = "squirtle-resumables",
    squirtleDiskState = "squirtle-disk-state"
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
    local data = Utils.readJson(getPath(entity)) or {}

    if data == textutils.empty_json_array then
        return {}
    end

    return data
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

---@param quest Quest
---@return Quest
function DatabaseService.createQuest(quest)
    quest.id = nextId("quests")
    pushEntity("quests", quest)

    return quest
end

---@return Quest[]
function DatabaseService.getQuests()
    return readEntities("quests")
end

---@param id integer
---@return Quest
function DatabaseService.getQuest(id)
    local quest = Utils.find(DatabaseService.getQuests(), function(quest)
        return quest.id == id
    end)

    if not quest then
        error(string.format("quest %d doesn't exist", id))
    end

    return quest
end

---@param quest Quest
function DatabaseService.updateQuest(quest)
    if not quest.id then
        error("can't update quest: no id assigned")
    end

    local quests = DatabaseService.getQuests()
    local index = Utils.findIndex(quests, function(candidate)
        return candidate.id == quest.id
    end)

    if not index then
        error(string.format("can't update quest: quest %d doesn't exist", quest.id))
    end

    quests[index] = quest
    writeEntities("quests", quests)
end

---@param type QuestType
---@return Quest?
function DatabaseService.getIssuedQuest(type)
    return Utils.find(DatabaseService.getQuests(), function(quest)
        return quest.status == "issued" and quest.type == type
    end)
end

---@param acceptedBy string
---@param questType QuestType
---@return Quest?
function DatabaseService.getAcceptedQuest(acceptedBy, questType)
    return Utils.find(DatabaseService.getQuests(), function(quest)
        return quest.status == "accepted" and quest.type == questType and quest.acceptedBy == acceptedBy
    end)
end

---@param allocatedBy string
---@param inventories string[]
---@param questId? integer
function DatabaseService.createAllocatedBuffer(allocatedBy, inventories, questId)
    local entityType = entityTypes.allocatedBuffers
    ---@type AllocatedBuffer
    local allocatedBuffer = {id = nextId(entityType), allocatedBy = allocatedBy, inventories = inventories, questId = questId}
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

---@param allocatedBy string
---@param questId? integer
---@return AllocatedBuffer?
function DatabaseService.findAllocatedBuffer(allocatedBy, questId)
    return Utils.find(DatabaseService.getAllocatedBuffers(), function(candidate)
        return candidate.allocatedBy == allocatedBy and (questId == nil or candidate.questId == questId)
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
