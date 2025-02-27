local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local readString = require "lib.ui.read-string"

---@class EditEntity
---@field window table
---@field properties EditEntityProperty[]
---@field index integer
local EditEntity = {}

---@alias EditEntityPropertyType "string"|"number"|"boolean"|"integer"

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
local function draw(self, entity, title)
    title = title or "Edit Entity"
    local win = self.window
    local w = win.getSize()
    win.clear()
    win.setCursorPos(1, 1)
    win.write(title)
    win.setCursorPos(1, 2)
    win.write(("-"):rep(w))
    win.setCursorPos(1, 3)

    local control = {x = 1, y = 1}
    local listY = 3

    for i = 1, #self.properties do
        local selected = self.index == i
        local y = listY + (i - 1)
        win.setCursorPos(1, y)

        if selected then
            win.write("> ")
        else
            win.write("  ")
        end

        win.write(self.properties[i].label .. ": ")

        if selected then
            control.x = win.getCursorPos()
            control.y = y
        else
            win.write(entity[self.properties[i].key])
        end
    end

    win.setCursorPos(1, listY + #self.properties + 1)

    if self.index == #self.properties + 1 then
        win.write("> Save")
    else
        win.write("  Save")
    end

    win.setCursorPos(1, listY + #self.properties + 2)

    if self.index == #self.properties + 2 then
        win.write("> Cancel")
    else
        win.write("  Cancel")
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

---@return EditEntity
function EditEntity.new()
    local w, h = term.getSize()

    ---@type EditEntity
    local instance = {properties = {}, window = window.create(term.current(), 1, 1, w, h), index = 1}

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
            entity[selected.key], key = readString(entity[selected.key], {cancel = controlKeys})
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
