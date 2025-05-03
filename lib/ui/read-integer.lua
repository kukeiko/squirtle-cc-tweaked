local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"

---@class ReadIntegerOptions
---@field cancel? table
---@field min? integer
---@field max? integer

---@param value? integer
---@param win table
local function drawValue(value, win)
    if value == nil then
        win.setCursorPos(1, 1)
        win.clearLine()
    else
        local offset = 0
        local width = win.getSize()

        if #tostring(value) >= width then
            offset = #value - (width - 2)
        end

        win.setCursorPos(1, 1)
        win.clearLine()

        if value ~= nil then
            win.write(tostring(value):sub(offset))
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
    drawValue(value, win)
    win.setCursorBlink(true)

    while true do
        local event, key = EventLoop.pull()

        if event == "key" then
            if Utils.contains(options.cancel or {}, key) then
                term.setCursorPos(x, y)
                print(value)
                return value, key
            end

            if key == keys.enter or key == keys.numPadEnter then
                term.setCursorPos(x, y)
                print(value)
                return value, key
            elseif key == keys.backspace then
                value = tonumber(tostring(value):sub(1, #tostring(value) - 1))
            end
        elseif event == "char" and tonumber(key) ~= nil then
            if value == nil or value == 0 then
                value = tonumber(key)
            else
                value = tonumber(tostring(value) .. key)
            end

            if options.max and value > options.max then
                value = options.max
            end

            if options.min and value < options.min then
                value = options.min
            end
        end

        drawValue(value, win)
    end
end
