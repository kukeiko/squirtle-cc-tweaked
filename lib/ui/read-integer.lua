local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"

---@class ReadIntegerOptions
---@field cancel? table
---@field min? integer
---@field max? integer

---@param win table
---@param value string
local function drawValue(win, value)
    if #value == 0 then
        win.setCursorPos(1, 1)
        win.clearLine()
    else
        local offset = 0
        local width = win.getSize()

        if #value >= width then
            offset = #value - (width - 2)
        end

        win.setCursorPos(1, 1)
        win.clearLine()

        if value ~= nil then
            win.write(string.sub(value, offset))
        end
    end
end

---@param value? integer
---@param options? ReadIntegerOptions
---@return integer?, integer
return function(value, options)
    options = options or {}
    local x, y = term.getCursorPos()
    local w = term.getSize()
    w = w - (x - 1)

    local win = window.create(term.current(), x, y, w, 1)
    local strValue = value == nil and "" or tostring(value)
    drawValue(win, strValue)
    win.setCursorBlink(true)

    while true do
        local event, key = EventLoop.pull()

        if event == "key" then
            if Utils.contains(options.cancel or {}, key) then
                term.setCursorPos(x, y)
                print(value)
                return value, key
            elseif key == keys.enter or key == keys.numPadEnter then
                term.setCursorPos(x, y)
                print(value)
                return value, key
            elseif key == keys.backspace then
                strValue = string.sub(strValue, 1, #strValue - 1)
                value = tonumber(strValue)
            end
        elseif event == "char" and (tonumber(key) ~= nil or (key == "-" and #strValue == 0)) then
            strValue = strValue .. key
            value = tonumber(strValue)

            if value ~= nil and options.max and value > options.max then
                value = options.max
                strValue = tostring(value)
            end

            if value ~= nil and options.min and value < options.min then
                value = options.min
                strValue = tostring(value)
            end
        end

        drawValue(win, strValue)
    end
end
