local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"

---@param values string[]
---@return integer
local function getLongestLength(values)
    local longest = 0

    for _, value in pairs(values) do
        if #value > longest then
            longest = #value
        end
    end

    return longest
end

---@param modal table
---@param value? string
---@param values string[]
local function draw(modal, value, values)
    local w, h = modal.getSize()

    for y = 1, h do
        modal.setCursorPos(1, y)

        if y == 1 then
            modal.write("\156")
            modal.write(string.rep("\140", w - 2))
            modal.blit("\147", colors.toBlit(colors.black), colors.toBlit(colors.white))
        elseif y == h then
            modal.write("\141")
            modal.write(string.rep("\140", w - 2))
            modal.write("\142")
        else
            modal.write("\149")
            local option = values[y - 1]

            if option == value then
                modal.write(Utils.pad(tostring(option), w - 2))
            else
                modal.setTextColor(colors.lightGray)
                modal.write(Utils.pad(tostring(option), w - 2))
                modal.setTextColor(colors.white)
            end

            modal.blit("\149", colors.toBlit(colors.black), colors.toBlit(colors.white))
        end
    end
end

---@param value? string
---@param values string[]
---@param optional? boolean
---@return string?
return function(value, values, optional)
    local originalValue = value
    local termWidth, termHeight = term.current().getSize()
    local longestWidth = getLongestLength(values)
    local modalWidth = longestWidth + 2 -- +2 for the borders
    local modalHeight = (#values + (optional and 1 or 0)) + 2 -- +2 for the borders
    local modalX = math.floor((termWidth - modalWidth) / 2)
    local modalY = math.ceil((termHeight - modalHeight) / 2)
    local modal = window.create(term.current(), modalX, modalY, modalWidth, modalHeight, true)

    if optional then
        values = Utils.copy(values)
        table.insert(values, 1, nil)
    end

    while true do
        draw(modal, value, values)
        local _, key = EventLoop.pull("key")

        if key == keys.up or key == keys.down then
            local index = Utils.indexOf(values, value) or 1

            if key == keys.up then
                index = ((index - 2) % #values) + 1
            elseif key == keys.down then
                index = (index % #values) + 1
            end

            value = values[index]
        elseif key == keys.space or key == keys.enter or key == keys.numPadEnter then
            modal.setVisible(false)

            return value
        elseif key == keys.f4 then
            modal.setVisible(false)

            return originalValue
        end
    end
end
