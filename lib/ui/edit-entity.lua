local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local readString = require "lib.ui.read-string"
local readInteger = require "lib.ui.read-integer"
local readOption = require "lib.ui.read-option"

---@class EditEntity
---@field window table
---@field properties EditEntityProperty[]
---@field index integer
---@field title string
local EditEntity = {}

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
---@field validate? fun(value:unknown, entity: table):boolean
---@field values? table

---@param self EditEntity
---@param entity table
local function draw(self, entity)
    local win = self.window
    win.setTextColor(colors.white)
    local w = win.getSize()
    win.clear()
    win.setCursorPos(1, 1)
    win.write(self.title)
    win.setCursorPos(1, 2)
    win.write(("-"):rep(w))
    win.setCursorPos(1, 3)

    local control = {x = 1, y = 1}
    local listY = 3
    win.setTextColor(colors.lightGray)

    for i = 1, #self.properties do
        local selected = self.index == i
        local y = listY + (i - 1)
        win.setCursorPos(1, y)

        if selected then
            win.setTextColor(colors.white)
        end

        win.write(self.properties[i].label .. ": ")
        win.setTextColor(colors.lightGray)

        if selected then
            control.x = win.getCursorPos()
            control.y = y
        else
            local value = entity[self.properties[i].key]

            if value == nil or value == "" then
                win.write(string.format("(%s)", self.properties[i].type))
            else
                win.setTextColor(colors.white)
                win.write(entity[self.properties[i].key])
                win.setTextColor(colors.lightGray)
            end
        end
    end

    win.setCursorPos(1, listY + #self.properties + 1)

    if self.index == #self.properties + 1 then
        win.setTextColor(colors.white)
        win.write("Save")
        win.setTextColor(colors.lightGray)
    else
        win.write("Save")
    end

    win.setCursorPos(1, listY + #self.properties + 2)

    if self.index == #self.properties + 2 then
        win.setTextColor(colors.white)
        win.write("Cancel")
        win.setTextColor(colors.lightGray)
    else
        win.write("Cancel")
    end

    win.setCursorPos(control.x, control.y)
end

---@param current integer
---@param max integer
local function nextIndex(current, max)
    if current + 1 > max then
        return 1
    end

    return current + 1
end

---@param current integer
---@param max integer
local function previousIndex(current, max)
    if current == 1 then
        return max
    end

    return current - 1
end

---@param title? string
---@return EditEntity
function EditEntity.new(title)
    local w, h = term.getSize()

    ---@type EditEntity
    local instance = {properties = {}, window = window.create(term.current(), 1, 1, w, h), index = 1, title = title or "Edit Entity"}

    return setmetatable(instance, {__index = EditEntity})
end

---@param self EditEntity
---@param type EditEntityPropertyType
---@param key string
---@param label? string
---@param options? EditEntityPropertyOptions
---@return EditEntity
function EditEntity.addField(self, type, key, label, options)
    ---@type EditEntityProperty
    local property = {type = type, key = key, label = label or key, options = options or {}}
    table.insert(self.properties, property)

    return self
end

---@generic T
---@param self EditEntity
---@param entity T
---@return T?
function EditEntity.run(self, entity)
    entity = Utils.copy(entity)
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
        else
            self.window.setCursorBlink(false)
            local _, k = EventLoop.pull("key")
            key = k
        end

        if key == keys.f4 then
            break
        elseif key == keys.up then
            self.index = previousIndex(self.index, #self.properties + 2)
        elseif key == keys.down then
            self.index = nextIndex(self.index, #self.properties + 2)
        elseif key == keys.enter then
            if self.index == #self.properties + 1 then
                result = entity
                break
            elseif self.index == #self.properties + 2 then
                break
            end
        end
    end

    self.window.clear()
    self.window.setCursorPos(1, 1)

    return result
end

return EditEntity
