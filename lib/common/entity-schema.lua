local Utils = require "lib.tools.utils"

---@class EntitySchema
---@field properties EntityProperty[]
local EntitySchema = {}

---@alias EntityPropertyType "string" | "number" | "boolean" | "integer"

---@class EntityProperty
---@field type EntityPropertyType
---@field key string
---@field label string
---@field options EntityPropertyOptions

-- [todo] ❌ min/max options are not validated anywhere
---@class EntityPropertyOptions
---@field optional? boolean
---@field minLength? number
---@field maxLength? number
---@field minValue? number
---@field maxValue? number
---@field values? table

function EntitySchema.new()
    ---@type EntitySchema
    local instance = {properties = {}}
    setmetatable(instance, {__index = EntitySchema})

    return instance
end

function EntitySchema:getProperties()
    return Utils.copy(self.properties)
end

function EntitySchema:getCount()
    return #self.properties
end

---@param type EntityPropertyType
---@param key string
---@param label? string
---@param options? EntityPropertyOptions
function EntitySchema:addProperty(type, key, label, options)
    ---@type EntityProperty
    local property = {type = type, key = key, label = label or key, options = options or {}}
    table.insert(self.properties, property)
end

---@param key string
---@param label? string
---@param options? EntityPropertyOptions
function EntitySchema:addInteger(key, label, options)
    self:addProperty("integer", key, label, options)
end

---@param key string
---@param label? string
---@param options? EntityPropertyOptions
function EntitySchema:addBoolean(key, label, options)
    self:addProperty("boolean", key, label, options)
end

---@param key string
---@param label? string
---@param options? EntityPropertyOptions
function EntitySchema:addString(key, label, options)
    self:addProperty("string", key, label, options)
end

return EntitySchema
