local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local SearchableList = require "lib.ui.searchable-list"

---@param shellWindow ShellWindow
return function(shellWindow)
    local start = os.epoch("utc")

    ---@return SearchableListOption[]
    local function getPulledEvents()
        local stats = EventLoop.getPulledEventStats()
        local duration = os.epoch("utc") - start

        local options = Utils.map(stats, function(quantity, event)
            ---@type SearchableListOption
            return {id = event, name = event, suffix = tostring(math.floor(quantity / (duration / 1000)))}
        end)

        start = os.epoch("utc")

        for k in pairs(stats) do
            stats[k] = 0
        end

        return options
    end

    local list = SearchableList.new(getPulledEvents(), "Pulled Events")

    EventLoop.run(function()
        while true do
            list:run()
        end
    end, function()
        while true do
            shellWindow:pullIsVisible()
            list:setOptions(getPulledEvents())
            shellWindow:runUntilInvisible(function()
                while true do
                    os.sleep(1)
                    list:setOptions(getPulledEvents())
                end
            end)
        end
    end)
end
