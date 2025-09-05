local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local readString = require "lib.ui.read-string"
local readInteger = require "lib.ui.read-integer"
local readBoolean = require "lib.ui.read-boolean"
local readOption = require "lib.ui.read-option"

---@class EditEntity
---@field window table
---@field properties EditEntityProperty[]
---@field index integer
---@field saveIndex integer?
---@field cancelIndex integer?
---@field title string
local EditEntity = {
    greaterZero = function(value)
        return value > 0, "must be greater than 0"
    end,
    notZero = function(value)
        return value ~= 0, "cannot be 0"
    end

}

---@alias EditEntityPropertyType "string" | "number" | "boolean" | "integer"

---@class EditEntityProperty
---@field type EditEntityPropertyType
---@field key string
---@field label string
---@field options EditEntityPropertyOptions

---@class EditEntityPropertyOptions
---@field optional? boolean
---@field minLength? number
---@field maxLength? number
---@field minValue? number
---@field maxValue? number
---@field validate? fun(value:unknown, entity: table) : boolean, string
---@field values? table

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

    for index, property in ipairs(self.properties) do
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
                win.write(string.format("(%s)", property.type))
            else
                win.setTextColor(colors.white)
                local value = entity[property.key]

                if value == true then
                    win.write("Yes")
                elseif value == false then
                    win.write("No")
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
    if self.index + 1 > #self.properties then
        return 1
    end

    return self.index + 1
end

---@param self EditEntity
---@return integer
local function previousIndex(self)
    if self.index == 1 then
        return #self.properties
    end

    return self.index - 1
end

---@param title? string
---@return EditEntity
function EditEntity.new(title)
    local w, h = term.getSize()

    ---@type EditEntity
    local instance = {properties = {}, window = window.create(term.current(), 1, 1, w, h), index = 1, title = title or "Edit Entity"}

    return setmetatable(instance, {__index = EditEntity})
end

---@param type EditEntityPropertyType
---@param key string
---@param label? string
---@param options? EditEntityPropertyOptions
---@return EditEntity
function EditEntity:addField(type, key, label, options)
    ---@type EditEntityProperty
    local property = {type = type, key = key, label = label or key, options = options or {}}
    table.insert(self.properties, property)
    self.saveIndex = #self.properties + 1
    self.cancelIndex = #self.properties + 2

    return self
end

---@param key string
---@param label? string
---@param options? EditEntityPropertyOptions
---@return EditEntity
function EditEntity:addInteger(key, label, options)
    return self:addField("integer", key, label, options)
end

---@param entity table
---@return table<string, string>
function EditEntity:validate(entity)
    ---@type table<string, string>
    local errors = {}

    for _, property in pairs(self.properties) do
        local value = entity[property.key]

        if value ~= nil and property.options.validate then
            local isValid, message = property.options.validate(value, entity)

            if not isValid then
                errors[property.key] = message
            end
        end
    end

    return errors
end

---@param entity table
function EditEntity:isValid(entity)
    for _, property in pairs(self.properties) do
        local value = entity[property.key]

        if not property.options.optional and value == nil then
            return false
        elseif property.options.validate and not property.options.validate(value, entity) then
            return false
        end
    end

    return true
end

---@generic T
---@param entity T
---@param savePath? string
---@return T
function EditEntity:run(entity, savePath)
    entity = Utils.copy(entity)

    if savePath then
        local saved = Utils.readJson(savePath) or {}

        for _, property in ipairs(self.properties) do
            if saved[property.key] ~= nil and entity[property.key] == nil then
                entity[property.key] = saved[property.key]
            end
        end
    end

    local result = nil

    while true do
        draw(self, entity)
        local selected = self.properties[self.index]
        local key = 0
        local controlKeys = {keys.f4, keys.up, keys.down}

        if selected and selected.type == "string" then
            if selected.options.values then
                entity[selected.key], key = readOption(entity[selected.key], selected.options.values)
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
            if self.index < #self.properties then
                self.index = nextIndex(self)
            elseif self.index == #self.properties and self:isValid(entity) then
                result = entity
                break
            end
        end
    end

    self.window.clear()
    self.window.setCursorPos(1, 1)
    self.window.setTextColor(colors.white)

    if result and savePath then
        local saved = {}

        for _, property in ipairs(self.properties) do
            if result[property.key] ~= nil then
                saved[property.key] = result[property.key]
            end
        end

        Utils.writeJson(savePath, saved)
    end

    return result
end

return EditEntity
