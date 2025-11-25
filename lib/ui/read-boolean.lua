local EventLoop = require "lib.tools.event-loop"

---@param value boolean
---@param canCancel? boolean
---@return boolean?, integer
return function(value, canCancel)
    local originalValue = value
    local cursorX, cursorY = term.current().getCursorPos()
    term.current().setCursorBlink(false)

    while true do
        term.current().setCursorPos(cursorX, cursorY)
        term.current().setTextColor(value and colors.white or colors.gray)
        term.current().write("Yes")
        term.current().setTextColor(colors.white)
        term.current().write(" / ")
        term.current().setTextColor(value and colors.gray or colors.white)
        term.current().write("No")

        local key = EventLoop.pullKey()

        if key == keys.enter or key == keys.numPadEnter then
            return value, key
        elseif key == keys.space then
            value = not value
        elseif canCancel and key == keys.up or key == keys.down then
            return value, key
        elseif canCancel and key == keys.f4 then
            return originalValue, key
        end
    end
end
