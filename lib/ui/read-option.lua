local EventLoop = require "lib.tools.event-loop"
local getOption = require "lib.ui.get-option"

---@param value? string
---@param values string[]
---@return string?, integer
return function(value, values)
    local originalValue = value
    local cursorX, cursorY = term.current().getCursorPos()

    term.current().setCursorBlink(false)
    value = value or values[1]

    while true do
        term.current().setCursorPos(cursorX, cursorY)
        term.current().setTextColor(colors.white)
        term.current().write(tostring(value) .. " \18")

        local _, key = EventLoop.pull("key")

        if key == keys.enter or key == keys.numPadEnter then
            value = getOption(value, values)
            return value, key
        elseif key == keys.up or key == keys.down then
            return value, key
        elseif key == keys.f4 then
            return originalValue, key
        end
    end
end
