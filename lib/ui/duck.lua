local Utils = require "lib.tools.utils"

--    _
-- __(.)<
-- \___)
local logo = {"    _  ", " __(.)<", " \\___) "}

---@param text? string|string[]
---@param duration? number
return function(text, duration)
    term.clear()
    local screenWidth, screenHeight = term.getSize()
    local logoWidth = logo[1]:len()
    local logoHeight = #logo
    local startY = math.floor((screenHeight - logoHeight) / 2)
    local startX = math.floor((screenWidth - logoWidth) / 2)

    for y = 1, #logo do
        term.setCursorPos(startX, y + startY)
        term.write(logo[y])
    end

    if text then
        if type(text) == "string" then
            text = {text}
        end

        for i, str in ipairs(text) do
            term.setCursorPos(1, startY + #logo + 1 + i)
            term.write(Utils.pad(str, screenWidth, " "))
        end
    end

    os.sleep(duration or 2)
    term.setCursorPos(1, 1)
    term.clear()
end
