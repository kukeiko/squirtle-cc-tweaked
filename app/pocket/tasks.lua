if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "pocket"}
end

local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local Shell = require "lib.system.shell"
local StorageService = require "lib.inventory.storage-service"
local TaskService = require "lib.system.task-service"
local SearchableList = require "lib.ui.searchable-list"

print(string.format("[tasks %s] connecting to services...", version()))
local storageService = Rpc.nearest(StorageService)
local taskService = Rpc.nearest(TaskService)

local idleTimeout = 30
local refreshIntervals = {dispense = 3, transfers = 1, missingDetails = 3, missing = 3}

---@param taskService TaskService|RpcClient
local function showMissingDetails(taskService)
    ---@return SearchableListOption[]
    local function getOptions()
        local report = taskService.getProvideItemsReport()
        local options = Utils.map(report.missingDetails, function(_, item)
            ---@type SearchableListOption
            return {id = item, name = item}
        end)

        return options
    end

    local searchableList = SearchableList.new(getOptions(), "Missing Info", idleTimeout, refreshIntervals.missingDetails, getOptions)

    while true do
        searchableList:run()
    end
end

---@param storageService StorageService|RpcClient
---@param taskService TaskService|RpcClient
local function showMissing(storageService, taskService)
    ---@return SearchableListOption[]
    local function getOptions()
        local itemDetails = storageService.getItemDetails()
        local report = taskService.getProvideItemsReport()
        local options = Utils.map(report.missing, function(quantity, item)
            ---@type SearchableListOption
            return {id = item, name = itemDetails[item].displayName, suffix = string.format("%d", quantity)}
        end)

        return options
    end

    local searchableList = SearchableList.new(getOptions(), "Missing Ingredients", idleTimeout, refreshIntervals.missing, getOptions)

    while true do
        searchableList:run()
    end
end

Shell:addWindow("Missing Ingredients", function(shellWindow)
    showMissing(storageService, taskService)
end)

Shell:addWindow("Missing Stored", function(shellWindow)
    showMissingDetails(taskService)
end)

Shell:run()
