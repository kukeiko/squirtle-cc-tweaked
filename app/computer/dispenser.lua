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

---@param storage StorageService|RpcClient
---@return SearchableListOption[]
local function getListOptions(storage)
    local stock = storage.getStock()
    local craftableStock = storage.getCraftableStock()
    local itemDetails = storage.getItemDetails()

    local nonEmptyStock = Utils.filterMap(stock, function(quantity, item)
        return quantity > 0 or (craftableStock[item] or 0) > 0
    end)

    local options = Utils.map(nonEmptyStock, function(quantity, item)
        local suffix = tostring(quantity + (craftableStock[item] or 0))

        ---@type SearchableListOption
        return {id = item, name = itemDetails[item].displayName, suffix = suffix}
    end)

    table.sort(options, function(a, b)
        return a.name < b.name
    end)

    return options
end

local function getListTitle()
    local commonTitle = "What item would you like transferred?"
    local titles = {"What item ya be needin'?", "I've got the goods!", commonTitle, commonTitle, commonTitle}

    return titles[math.random(#titles)]
end

---@param left? string
---@param right? string
local function drawStatusBar(left, right)
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

    if craftable and craftable > 0 then
        total = available + craftable
        print(string.format(" - Craftable: %d", craftable))
        print(string.format(" - Total: %d", total))
    end

    local quantity = readInteger(nil, {max = total})

    if quantity and quantity > 0 then
        quantity = math.min(total, quantity)
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

        -- [todo]
        -- taskService.deleteTask(task.id)
    end

    term.redirect(original)
end

---@param storageService StorageService|RpcClient
---@param taskService TaskService|RpcClient
local function showTransfers(storageService, taskService)
    term.clear()
    term.setCursorPos(1, 1)
    print("transfers!")
    drawStatusBar("< Items")
    EventLoop.pullKey(keys.left)
end

---@param storageService StorageService|RpcClient
---@param taskService TaskService|RpcClient
local function showItemList(storageService, taskService)
    local idleTimeout = 5
    local refreshInterval = 3
    local options = getListOptions(storageService)
    local title = getListTitle()
    local _, termHeight = term.getSize()
    local searchableList = SearchableList.new(options, title, idleTimeout, refreshInterval, function()
        return getListOptions(storageService)
        -- end, nil, termHeight - 2)
    end, nil, nil)

    while true do
        term.clear()
        -- drawStatusBar(nil, "Transfers >")

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
            -- showTransfers(storageService, taskService)
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
