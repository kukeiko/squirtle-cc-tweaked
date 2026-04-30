local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local TaskService = require "lib.system.task-service"
local SearchableList = require "lib.ui.searchable-list"
local TableViewer = require "lib.ui.table-viewer"

---@param taskId integer
---@param taskService TaskService|RpcClient
local function showTask(taskId, taskService)
    local task = taskService.getTask(taskId)
    local tablewViewer = TableViewer.new(task, task.type .. " #" .. task.id)
    tablewViewer:run()
end

---@param shellWindow ShellWindow
return function(shellWindow)
    print("[connect] to task service...")

    local taskService = Rpc.nearest(TaskService)

    local function getOptions()
        local tasks = taskService.getTasks()

        return Utils.map(tasks, function(task)
            ---@type SearchableListOption
            local option = {id = tostring(task.id), name = task.type, suffix = "#" .. task.id}

            return option
        end)
    end

    local list = SearchableList.new(getOptions(), "Tasks", 60, 1, getOptions)

    while true do
        local selected, action = list:run()

        if selected and action == "select" then
            showTask(tonumber(selected.id) or error("not a number"), taskService)
        elseif selected and action == "delete" then
            taskService.deleteTask(tonumber(selected.id) or error("not a number"))
        end
    end
end
