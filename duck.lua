--    _
-- __(.)<
-- \___)
local logo = {"    _  ", " __(.)<", " \\___) "}

return function()
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

    os.sleep(1)
    term.setCursorPos(1, 1)
    term.clear()
end
