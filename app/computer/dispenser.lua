if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "computer"}
end

local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local RemoteService = require "lib.system.remote-service"
local StorageService = require "lib.inventory.storage-service"
local TaskService = require "lib.system.task-service"
local Shell = require "lib.system.shell"
local SearchableList = require "lib.ui.searchable-list"
local readInteger = require "lib.ui.read-integer"
local showLogs = require "lib.system.windows.logs-window"

local idleTimeout = 30
local refreshIntervals = {dispense = 3, transfers = 1, missing = 1}

---@param storageService StorageService|RpcClient
---@param taskService TaskService|RpcClient
---@param selection SearchableListOption
local function showDispenseScreen(storageService, taskService, selection)
    local width, height = term.getSize()
    local win = window.create(term.current(), 1, 1, width, height)
    local original = term.redirect(win)
    local available = storageService.getItemCount(selection.id)
    local craftable = storageService.getCraftableCount(selection.id)
    local total = available
    local stash = os.getComputerLabel()
    print(string.format("How many %s?", selection.name))
    print(string.format(" - Stored: %d", available))

    if craftable then
        print(string.format(" - Craftable: %d", craftable))

        if craftable > 0 then
            total = available + craftable
            print(string.format(" - Total: %d", total))
        end
    end

    local quantity = readInteger()

    if quantity and quantity > 0 then
        term.clear()
        term.setCursorPos(1, 1)

        if quantity > available then
            print("[wait] crafting & transferring...")
        else
            print("[wait] transferring...")
        end

        taskService.provideItems({
            issuedBy = os.getComputerLabel(),
            craftMissing = true,
            items = {[selection.id] = quantity},
            to = stash,
            label = tostring(os.epoch("utc")),
            autoDelete = true,
            skipAwait = true
        })
    end

    term.redirect(original)
end

---@param storageService StorageService|RpcClient
---@param taskService TaskService|RpcClient
local function showMissing(storageService, taskService)
    ---@return SearchableListOption[]
    local function getOptions()
        local itemDetails = storageService.getItemDetails()
        local report = taskService.getProvideItemsReport(os.getComputerLabel())
        local options = Utils.map(report.missing, function(quantity, item)
            ---@type SearchableListOption
            return {id = item, name = itemDetails[item].displayName, suffix = string.format("%d", quantity)}
        end)

        return options
    end

    local searchableList = SearchableList.new(getOptions(), "Missing", idleTimeout, refreshIntervals.missing, getOptions)

    while true do
        searchableList:run()
    end
end

---@param storageService StorageService|RpcClient
---@param taskService TaskService|RpcClient
local function showTransfers(storageService, taskService)
    ---@return SearchableListOption[]
    local function getOptions()
        local itemDetails = storageService.getItemDetails()
        local report = taskService.getProvideItemsReport(os.getComputerLabel())
        local options = Utils.map(report.wanted, function(quantity, item)
            ---@type SearchableListOption
            return {id = item, name = itemDetails[item].displayName, suffix = string.format("%d/%d", report.found[item] or 0, quantity)}
        end)

        return options
    end

    local searchableList = SearchableList.new(getOptions(), "Transfers", idleTimeout, refreshIntervals.transfers, getOptions)

    while true do
        searchableList:run()
    end
end

local function getDispenseItemsListTitle()
    local commonTitle = "What item would you like transferred?"
    local titles = {"What item ya be needin'?", "I've got the goods!", commonTitle, commonTitle, commonTitle}

    return titles[math.random(#titles)]
end

---@param storageService StorageService|RpcClient
---@param taskService TaskService|RpcClient
local function showItemList(storageService, taskService)
    ---@return SearchableListOption[]
    local function getOptions()
        local stock = storageService.getStock()
        local maxStock = storageService.getMaxStock()
        local craftableStock = storageService.getCraftableStock()
        local itemDetails = storageService.getItemDetails()

        local options = Utils.map(stock, function(quantity, item)
            local suffix = string.format("%d/%d", quantity + (craftableStock[item] or 0), maxStock[item])

            ---@type SearchableListOption
            return {id = item, name = itemDetails[item].displayName, suffix = suffix}
        end)

        table.sort(options, function(a, b)
            return a.name < b.name
        end)

        return options
    end

    local title = getDispenseItemsListTitle()
    local searchableList = SearchableList.new(getOptions(), title, idleTimeout, refreshIntervals.dispense, getOptions)

    while true do
        local selection = searchableList:run()

        if selection then
            showDispenseScreen(storageService, taskService, selection)
        end
    end
end

print(string.format("[dispenser %s] connecting to services...", version()))
local storageService = Rpc.nearest(StorageService)
local taskService = Rpc.nearest(TaskService)

Shell:addWindow("Items", function()
    showItemList(storageService, taskService)
end)

Shell:addWindow("Transfers", function()
    showTransfers(storageService, taskService)
end)

Shell:addWindow("Missing", function()
    showMissing(storageService, taskService)
end)

Shell:addWindow("Logs", showLogs)

Shell:addWindow("RPC", function()
    RemoteService.run({"dispenser"})
end)

Shell:run()
