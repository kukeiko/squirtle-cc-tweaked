local Utils = require "lib.utils"
local EventLoop = require "lib.event-loop"

---@class ReadStringOptions
---@field cancel? table

---@param value string
---@param win table
local function drawValue(value, win)
    local offset = 0
    local width = win.getSize()

    if #value >= width then
        offset = #value - (width - 2)
    end

    win.setCursorPos(1, 1)
    win.clearLine()
    win.write(value:sub(offset))
end

---@param value string
---@param options? ReadStringOptions
---@return string, integer
return function(value, options)
    options = options or {}
    local x, y = term.getCursorPos()
    local w = term.getSize()
    w = w - (x - 1)

    local win = window.create(term.current(), x, y, w, 1)
    drawValue(value, win)
    win.setCursorBlink(true)

    while true do
        local event, key = EventLoop.pull()

        if event == "key" then
            if Utils.contains(options.cancel or {}, key) then
                return value, key
            end

            if key == keys.enter then
                return value, key
            elseif key == keys.backspace then
                value = value:sub(1, #value - 1)
            end
        elseif event == "char" then
            value = value .. key
        end

        drawValue(value, win)
    end
end
