if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local EventLoop = require "lib.tools.event-loop"
local RemoteService = require "lib.systems.runtime.remote-service"
local StorageService = require "lib.systems.storage.storage-service"
local TaskService = require "lib.systems.task.task-service"
local SearchableList = require "lib.ui.searchable-list"
local readInteger = require "lib.ui.read-integer"

local idleTimeout = 30
local refreshInterval = 3

---@param storageService StorageService|RpcClient
---@return SearchableListOption[]
local function getDispenseItemsListOptions(storageService)
    local stock = storageService.getStock()
    local craftableStock = storageService.getCraftableStock()
    local itemDetails = storageService.getItemDetails()

    local options = Utils.map(stock, function(quantity, item)
        local suffix = tostring(quantity + (craftableStock[item] or 0))

        ---@type SearchableListOption
        return {id = item, name = itemDetails[item].displayName, suffix = suffix}
    end)

    table.sort(options, function(a, b)
        return a.name < b.name
    end)

    return options
end

local function getDispenseItemsListTitle()
    local commonTitle = "What item would you like transferred?"
    local titles = {"What item ya be needin'?", "I've got the goods!", commonTitle, commonTitle, commonTitle}

    return titles[math.random(#titles)]
end

---@param storageService StorageService|RpcClient
---@param taskService TaskService|RpcClient
---@return SearchableListOption[]
local function getTransfersListOptions(storageService, taskService)
    local itemDetails = storageService.getItemDetails()
    local report = taskService.getProvideItemsReport(os.getComputerLabel())
    local options = Utils.map(report.wanted, function(quantity, item)
        ---@type SearchableListOption
        return {id = item, name = itemDetails[item].displayName, suffix = string.format("%d/%d", report.found[item] or 0, quantity)}
    end)

    return options
end

---@param storageService StorageService|RpcClient
---@param taskService TaskService|RpcClient
---@return SearchableListOption[]
local function getMissingListOptions(storageService, taskService)
    local itemDetails = storageService.getItemDetails()
    local report = taskService.getProvideItemsReport(os.getComputerLabel())
    local options = Utils.map(report.missing, function(quantity, item)
        ---@type SearchableListOption
        return {id = item, name = itemDetails[item].displayName, suffix = string.format("%d", quantity)}
    end)

    return options
end

---@param left? string
---@param right? string
local function drawNavBar(left, right)
    local termWidth, termHeight = term.getSize()
    term.setCursorPos(1, termHeight - 1)
    term.write(string.rep("-", termWidth))

    if left then
        term.setCursorPos(1, termHeight)
        term.write(left)
    end

    if right then
        term.setCursorPos(termWidth - #right, termHeight)
        term.write(right)
    end
end

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
            autoDelete = true
        })
    end

    term.redirect(original)
end

---@param storageService StorageService|RpcClient
---@param taskService TaskService|RpcClient
local function showMissing(storageService, taskService)
    local options = getMissingListOptions(storageService, taskService)
    local title = "Missing Ingredients"
    local _, termHeight = term.getSize()
    local searchableList = SearchableList.new(options, title, idleTimeout, refreshInterval, function()
        return getMissingListOptions(storageService, taskService)
    end, nil, termHeight - 2)

    while true do
        term.clear()
        drawNavBar("< Transfers")

        ---@type "transfers"?
        local action

        EventLoop.waitForAny(function()
            searchableList:run()
        end, function()
            EventLoop.pullKey(keys.left)
            action = "transfers"
        end)

        if action == "transfers" then
            return nil
        end
    end
end

---@param storageService StorageService|RpcClient
---@param taskService TaskService|RpcClient
local function showTransfers(storageService, taskService)
    local options = getTransfersListOptions(storageService, taskService)
    local title = "Transfers"
    local _, termHeight = term.getSize()
    local searchableList = SearchableList.new(options, title, idleTimeout, refreshInterval, function()
        return getTransfersListOptions(storageService, taskService)
    end, nil, termHeight - 2)

    while true do
        term.clear()
        drawNavBar("< Items", "Missing >")

        ---@type "items"|"missing"?
        local action

        EventLoop.waitForAny(function()
            searchableList:run()
        end, function()
            EventLoop.pullKey(keys.left)
            action = "items"
        end, function()
            EventLoop.pullKey(keys.right)
            action = "missing"
        end)

        if action == "items" then
            return nil
        elseif action == "missing" then
            showMissing(storageService, taskService)
        end
    end
end

---@param storageService StorageService|RpcClient
---@param taskService TaskService|RpcClient
local function showItemList(storageService, taskService)
    local options = getDispenseItemsListOptions(storageService)
    local title = getDispenseItemsListTitle()
    local _, termHeight = term.getSize()
    local searchableList = SearchableList.new(options, title, idleTimeout, refreshInterval, function()
        return getDispenseItemsListOptions(storageService)
    end, nil, termHeight - 2)

    while true do
        term.clear()
        drawNavBar(nil, "Transfers >")

        ---@type SearchableListOption?
        local selection
        EventLoop.waitForAny(function()
            selection = searchableList:run()
        end, function()
            EventLoop.pullKey(keys.right)
        end)

        if selection then
            showDispenseScreen(storageService, taskService, selection)
        else
            showTransfers(storageService, taskService)
        end
    end
end

EventLoop.run(function()
    RemoteService.run({"dispenser"})
end, function()
    print(string.format("[dispenser %s] connecting to services...", version()))
    local storageService = Rpc.nearest(StorageService)
    local taskService = Rpc.nearest(TaskService)
    showItemList(storageService, taskService)
end)
