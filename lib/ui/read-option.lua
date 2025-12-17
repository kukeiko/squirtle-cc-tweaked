local EventLoop = require "lib.tools.event-loop"
local getOption = require "lib.ui.get-option"

---@param value? string
---@param values string[]
---@param optional? boolean
---@return string?, integer
return function(value, values, optional)
    local originalValue = value
    local cursorX, cursorY = term.current().getCursorPos()

    term.current().setCursorBlink(false)

    while true do
        term.current().setCursorPos(cursorX, cursorY)
        term.current().setTextColor(colors.white)
        term.current().write(tostring(value) .. " \18")

        local _, key = EventLoop.pull("key")

        if key == keys.space then
            value = getOption(value, values, optional)
            return value, key
        elseif key == keys.up or key == keys.down or key == keys.enter or key == keys.numPadEnter then
            return value, key
        elseif key == keys.f4 then
            return originalValue, key
        end
    end
end
