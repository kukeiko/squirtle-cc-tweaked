local SearchableList = require "lib.ui.searchable-list"

---@class TableViewer
---@field data table
---@field title string
local TableViewer = {}

---@param data table
local function getOptions(data)
    ---@type SearchableListOption[]
    local options = {}

    for key, value in pairs(data) do
        local suffix = ""

        if type(value) == "table" then
            suffix = "table"
        else
            suffix = tostring(value)
        end

        ---@type SearchableListOption
        local option = {id = tostring(key), name = tostring(key), suffix = suffix, data = value}
        table.insert(options, option)
    end

    return options
end

---@param data table
---@param title string
local function showList(data, title)
    while true do
        local list = SearchableList.new(getOptions(data), title)
        local selected = list:run()

        if selected then
            if type(selected.data) == "table" then
                showList(selected.data, string.format("%s > %s", title, selected.name))
            end
        else
            break
        end
    end
end

---@param data table
---@param title string
function TableViewer.new(data, title)
    ---@type TableViewer
    local instance = {data = data, title = title}
    setmetatable(instance, {__index = TableViewer})

    return instance
end

function TableViewer:run()
    showList(self.data, self.title)
end

return TableViewer
