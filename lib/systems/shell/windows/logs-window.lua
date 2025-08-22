local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Logger = require "lib.tools.logger"
local SearchableList = require "lib.ui.searchable-list"
local TableViewer = require "lib.ui.table-viewer"

---@return SearchableListOption[]
local function getLogMessages()
    local options = Utils.map(Utils.reverse(Logger.getMessages()), function(message)
        ---@type SearchableListOption
        local option = {id = tostring(message.id), name = message.message, suffix = message.timestamp, data = message}

        return option
    end)

    return options
end

---@param message LogMessage
local function showLogMessage(message)
    local viewer = TableViewer.new(message, "Log Message")
    viewer:run()
end

---@param shellWindow ShellWindow
return function(shellWindow)
    local list = SearchableList.new(getLogMessages(), "Log Messages")

    EventLoop.run(function()
        while true do
            local selected = list:run()

            if selected then
                showLogMessage(selected.data)
            end
        end
    end, function()
        while true do
            shellWindow:pullIsVisible()
            list:setOptions(getLogMessages())
            shellWindow:runUntilInvisible(function()
                while true do
                    Logger.pullLoggedMessage()
                    list:setOptions(getLogMessages())
                end
            end)
        end
    end)
end
