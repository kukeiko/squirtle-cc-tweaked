local Utils = require "lib.tools.utils"

---@class EntityFile
---@field id integer
---@field entities table[]
---
---@class EntityRepository
---@field name string
---@field autoId boolean
---@field idField string
local EntityRepository = {}

---@param name string
---@param autoId boolean
---@param idField string
---@return EntityRepository
function EntityRepository.new(name, autoId, idField)
    ---@type EntityRepository
    local instance = {name = name, autoId = autoId, idField = idField}
    setmetatable(instance, {__index = EntityRepository})

    return instance
end

---@return string
function EntityRepository:getFilePath()
    return string.format("data/entities/%s.json", self.name)
end

---@return EntityFile
function EntityRepository:loadFile()
    ---@type EntityFile
    local file = Utils.readJson(self:getFilePath()) or {}
    file.id = file.id or 1
    file.entities = file.entities or {}

    return file
end

---@param file EntityFile
function EntityRepository:writeFile(file)
    Utils.writeJson(self:getFilePath(), file)
end

---@param entity table
---@return table
function EntityRepository:create(entity)
    local file = self:loadFile()

    if self.autoId then
        entity[self.idField] = file.id
        file.id = file.id + 1
    end

    table.insert(file.entities, entity)
    self:writeFile(file)

    return entity
end

---@param entity table
function EntityRepository:update(entity)
    if not entity[self.idField] or entity[self.idField] == 0 then
        error(string.format("can't update %s: no id assigned", self.name))
    end

    local file = self:loadFile()
    local index = Utils.findIndex(file.entities, function(candidate)
        return candidate[self.idField] == entity[self.idField]
    end)

    if not index then
        error(string.format("can't update %s: entity #%s not found", self.name, tostring(entity[self.idField])))
    end

    file.entities[index] = entity
    self:writeFile(file)
end

function EntityRepository:save(entity)
    if not entity[self.idField] or entity[self.idField] == 0 or entity[self.idField] == "" then
        if self.autoId then
            return self:create(entity)
        else
            error(string.format("can't save %s: no id assigned", self.name))
        end
    end

    local file = self:loadFile()
    local index = Utils.findIndex(file.entities, function(candidate)
        return candidate[self.idField] == entity[self.idField]
    end)

    if index then
        file.entities[index] = entity
        self:writeFile(file)
        return entity
    else
        return self:create(entity)
    end
end

---@param id integer|string
function EntityRepository:delete(id)
    if not id then
        error(string.format("can't delete %s: id was falsy", self.name))
    end

    local file = self:loadFile()
    local index = Utils.findIndex(file.entities, function(candidate)
        return candidate[self.idField] == id
    end)

    if not index then
        error(string.format("can't delete %s: entity #%s not found", self.name, tostring(id)))
    end

    table.remove(file.entities, index)
    self:writeFile(file)
end

---@return table[]
function EntityRepository:getAll()
    return self:loadFile().entities
end

---@param id integer|string
---@return table?
function EntityRepository:find(id)
    local file = self:loadFile()

    return Utils.find(file.entities, function(candidate)
        return candidate[self.idField] == id
    end)
end

return EntityRepository
