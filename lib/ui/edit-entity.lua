local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local EntitySchema = require "lib.common.entity-schema"
local readString = require "lib.ui.read-string"
local readInteger = require "lib.ui.read-integer"
local readBoolean = require "lib.ui.read-boolean"
local readOption = require "lib.ui.read-option"

---@class EditEntity
---@field window table
---@field index integer
---@field title string
---@field savePath string?
---@field schema EntitySchema
---@field validators table<string, function>
local EditEntity = {
    greaterZero = function(value)
        return value > 0, "must be > 0"
    end,
    notZero = function(value)
        return value ~= 0, "can't be 0"
    end
}

---@class EditEntityPropertyOptions : EntityPropertyOptions
---@field validate? fun(value:unknown, entity: table) : boolean, string

---@param self EditEntity
---@param entity table
local function draw(self, entity)
    local win = self.window
    win.setTextColor(colors.white)
    local width = win.getSize()
    win.clear()
    win.setCursorPos(1, 1)
    win.write(self.title)
    win.setCursorPos(1, 2)
    win.write(string.rep("-", width))
    win.setCursorPos(1, 3)

    local control = {x = 1, y = 1}
    local listStartY = 3
    win.setTextColor(colors.lightGray)
    local errors = self:validate(entity)
    local properties = self.schema:getProperties()

    for index, property in ipairs(properties) do
        local selected = self.index == index
        local drawY = listStartY + (index - 1)
        win.setCursorPos(1, drawY)

        if selected then
            win.setTextColor(colors.white)
        end

        win.write(property.label .. ": ")
        win.setTextColor(colors.lightGray)

        if selected then
            control.x = win.getCursorPos()
            control.y = drawY
        else
            local value = entity[property.key]

            if value == nil or value == "" then
                if property.options.optional then
                    win.write(string.format("(%s, optional)", property.type))
                else
                    win.write(string.format("(%s)", property.type))
                end
            else
                win.setTextColor(colors.white)
                local value = entity[property.key]

                if value == true then
                    win.setTextColor(colors.white)
                    win.write("Yes /")
                    win.setTextColor(colors.gray)
                    win.write(" No")
                elseif value == false then
                    win.setTextColor(colors.gray)
                    win.write("Yes")
                    win.setTextColor(colors.white)
                    win.write(" / No")
                else
                    win.write(entity[property.key])
                end

                if errors[property.key] then
                    win.setTextColor(colors.red)
                    win.write(" " .. errors[property.key])
                end

                win.setTextColor(colors.lightGray)
            end
        end
    end

    win.setCursorPos(control.x, control.y)
end

---@param self EditEntity
---@return integer
local function nextIndex(self)
    if self.index + 1 > self.schema:getCount() then
        return 1
    end

    return self.index + 1
end

---@param self EditEntity
---@return integer
local function previousIndex(self)
    if self.index == 1 then
        return self.schema:getCount()
    end

    return self.index - 1
end

---@param title? string
---@param savePath? string
---@return EditEntity
function EditEntity.new(title, savePath)
    local w, h = term.getSize()

    ---@type EditEntity
    local instance = {
        window = window.create(term.current(), 1, 1, w, h),
        index = 1,
        title = title or "Edit Entity",
        savePath = savePath,
        schema = EntitySchema.new(),
        validators = {}
    }

    return setmetatable(instance, {__index = EditEntity})
end

function EditEntity:getSchema()
    return self.schema
end

---@param type EntityPropertyType
---@param key string
---@param label? string
---@param options? EditEntityPropertyOptions
---@return EditEntity
function EditEntity:addField(type, key, label, options)
    options = options or {}

    if options.validate then
        self.validators[key] = options.validate
        options.validate = nil
    end

    self.schema:addProperty(type, key, label, options --[[@as EntityPropertyOptions]] )

    return self
end

---@param key string
---@param label? string
---@param options? EditEntityPropertyOptions
---@return EditEntity
function EditEntity:addInteger(key, label, options)
    return self:addField("integer", key, label, options)
end

---@param key string
---@param label? string
---@param options? EditEntityPropertyOptions
---@return EditEntity
function EditEntity:addBoolean(key, label, options)
    return self:addField("boolean", key, label, options)
end

---@param key string
---@param label? string
---@param options? EditEntityPropertyOptions
---@return EditEntity
function EditEntity:addString(key, label, options)
    return self:addField("string", key, label, options)
end

---@param entity table
---@return table<string, string>
function EditEntity:validate(entity)
    ---@type table<string, string>
    local errors = {}

    for _, property in pairs(self.schema:getProperties()) do
        local value = entity[property.key]
        local validator = self.validators[property.key]

        if value ~= nil and validator then
            local isValid, message = validator(value, entity)

            if not isValid then
                errors[property.key] = message
            end
        end
    end

    return errors
end

---@param entity table
function EditEntity:isValid(entity)
    for _, property in pairs(self.schema:getProperties()) do
        local value = entity[property.key]
        local validator = self.validators[property.key]

        if not property.options.optional and value == nil then
            return false
        elseif validator and not validator(value, entity) then
            return false
        end
    end

    return true
end

---@generic T
---@param entity? T
---@param skipIfValid? boolean
---@return T
function EditEntity:run(entity, skipIfValid)
    entity = Utils.copy(entity or {})

    if self.savePath then
        local saved = Utils.readJson(self.savePath) or {}

        for _, property in ipairs(self.schema:getProperties()) do
            -- if saved[property.key] ~= nil and entity[property.key] == nil then
            if saved[property.key] ~= nil then
                entity[property.key] = saved[property.key]
            end
        end
    end

    if skipIfValid and self:isValid(entity) then
        return entity
    end

    local result = nil
    local properties = self.schema:getProperties()

    while true do
        draw(self, entity)
        local selected = properties[self.index]
        local key = 0
        local controlKeys = {keys.f4, keys.up, keys.down}

        if selected and selected.type == "string" then
            if selected.options.values then
                entity[selected.key], key = readOption(entity[selected.key], selected.options.values, selected.options.optional)
            else
                entity[selected.key], key = readString(entity[selected.key], {cancel = controlKeys})
            end
        elseif selected and selected.type == "integer" then
            entity[selected.key], key = readInteger(entity[selected.key], {cancel = controlKeys})
        elseif selected and selected.type == "boolean" then
            entity[selected.key], key = readBoolean(entity[selected.key], true)
        else
            self.window.setCursorBlink(false)
            local _, k = EventLoop.pull("key")
            key = k
        end

        if key == keys.f4 then
            break
        elseif key == keys.up then
            self.index = previousIndex(self)
        elseif key == keys.down then
            self.index = nextIndex(self)
        elseif key == keys.enter or key == keys.numPadEnter then
            if self.index < #properties then
                self.index = nextIndex(self)
            elseif self.index == #properties and self:isValid(entity) then
                result = entity
                break
            end
        end
    end

    self.window.clear()
    self.window.setCursorPos(1, 1)
    self.window.setTextColor(colors.white)
    self.window.setCursorBlink(false)

    if result and self.savePath then
        local saved = {}

        for _, property in ipairs(properties) do
            if result[property.key] ~= nil then
                saved[property.key] = result[property.key]
            end
        end

        Utils.writeJson(self.savePath, saved)
    end

    return result
end

return EditEntity
