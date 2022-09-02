---@param current number
---@param total number
---@param x integer|nil
---@param y integer|nil
---@return integer, integer
return function(current, total, x, y)
    if not x or not y then
        x, y = term.getCursorPos()
    end

    ---@type integer
    local termWidth = term.getSize()
    local numProgressChars = termWidth - 2

    local numCharsDone = math.ceil((current / total) * numProgressChars)
    local numCharsOpen = numProgressChars - numCharsDone
    term.setCursorPos(x, y)
    term.write("[" .. string.rep("=", numCharsDone) .. string.rep(" ", numCharsOpen) .. "]")

    return x, y
end
