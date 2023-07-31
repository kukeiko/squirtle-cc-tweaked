local Backpack = require "squirtle.backpack"
local Utils = require "utils"

---@param items table<string, integer>
local function getMissing(items)
    ---@type table<string, integer>
    local open = {}
    local stock = Backpack.getStock()

    for item, required in pairs(items) do
        local missing = required - (stock[item] or 0)

        if missing > 0 then
            open[item] = required - (stock[item] or 0)
        end
    end

    return open
end

---@param items table<string, integer>
return function(items)
    while true do
        ---@type table<string, integer>
        local open = getMissing(items)

        if Utils.count(open) == 0 then
            term.clear()
            term.setCursorPos(1, 1)
            return nil
        end

        term.clear()
        term.setCursorPos(1, 1)
        print("Required Items")
        local width = term.getSize()
        print(string.rep("-", width))

        for item, missing in pairs(open) do
            print(string.format("%dx %s", missing, item))
        end

        os.pullEvent("turtle_inventory")
    end
end
