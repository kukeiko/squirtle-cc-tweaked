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

---@param parentTaskId integer?
---@param tasks Task[]
---@return Task[]
local function getChildTasks(parentTaskId, tasks)
    return Utils.filter(tasks, function(candidate)
        return candidate.partOfTaskId == parentTaskId
    end)
end

---@param tasks Task[]
---@return Task[]
local function toOrderedTasksByHierarchy(tasks)
    ---@type Task[]
    local ordered = {}

    ---@param parentTaskId integer?
    local function addTasks(parentTaskId)
        for _, child in ipairs(getChildTasks(parentTaskId, tasks)) do
            table.insert(ordered, child)
            addTasks(child.id)
        end
    end

    addTasks(nil)

    return ordered
end

---@param shellWindow ShellWindow
return function(shellWindow)
    print("[connect] to task service...")

    local taskService = Rpc.nearest(TaskService)

    local function getOptions()
        local tasks = toOrderedTasksByHierarchy(taskService.getTasks())

        return Utils.map(tasks, function(task)
            local indicator = " "

            if task.status == "failed" then
                indicator = "\19"
            elseif task.status == "accepted" then
                indicator = "\07"
            end

            local name = task.partOfTaskId ~= nil and string.format("\183%s", task.type) or task.type
            local suffix = string.format("#%d%s", task.id, indicator)
            ---@type SearchableListOption
            local option = {id = tostring(task.id), name = name, suffix = suffix}

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
