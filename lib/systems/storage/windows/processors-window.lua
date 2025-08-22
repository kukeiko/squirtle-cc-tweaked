local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local SearchableList = require "lib.ui.searchable-list"

---@param processors StorageProcessorOptions
---@return SearchableListOption[]
local function getProcessorList(processors)
    return Utils.map(processors, function(processor, name)
        ---@type SearchableListOption
        local option = {id = name, name = name, suffix = processor.enabled and "\07" or ""}

        return option
    end)
end

---@param processors StorageProcessorOptions
return function(processors)
    ---@param shellWindow ShellWindow
    return function(shellWindow)
        local list = SearchableList.new(getProcessorList(processors), "Processors")

        EventLoop.run(function()
            while true do
                local selected = list:run()

                if selected then
                    processors[selected.id].enabled = not processors[selected.id].enabled
                    list:setOptions(getProcessorList(processors))
                end
            end
        end)
    end
end
