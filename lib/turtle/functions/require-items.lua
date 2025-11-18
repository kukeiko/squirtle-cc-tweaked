local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ItemApi = require "lib.inventory.item-api"
local SearchableList = require "lib.ui.searchable-list"

---@param TurtleApi TurtleApi
---@param items ItemStock
---@param alwaysUseShulkers? boolean
---@return ItemStock, integer
local function getOpen(TurtleApi, items, alwaysUseShulkers)
    local openStock, requiredShulkers = TurtleApi.getOpenStock(items, alwaysUseShulkers)

    if requiredShulkers > 0 then
        return {[ItemApi.shulkerBox] = requiredShulkers}, requiredShulkers
    else
        return openStock, 0
    end
end

---@param open ItemStock
---@return SearchableListOption[]
local function getOptions(open)
    return Utils.map(open, function(quantity, item)
        ---@type SearchableListOption
        local option = {id = item, name = item, suffix = string.format("%dx", quantity)}

        return option
    end)
end

---@param TurtleApi TurtleApi
---@param items ItemStock
---@param open ItemStock
local function requireItemsInInventory(TurtleApi, items, open)
    local searchableList = SearchableList.new(getOptions(open), "Required Items")

    EventLoop.waitForAny(function()
        while true do
            searchableList:run()
        end
    end, function()
        while true do
            open = getOpen(TurtleApi, items)

            if Utils.isEmpty(open) then
                break
            end

            searchableList:setOptions(getOptions(open))

            while true do
                local event = EventLoop.pull()

                if event == "turtle_inventory" then
                    break
                end
            end
        end
    end)

    term.clear()
    term.setCursorPos(1, 1)
end

---@param TurtleApi TurtleApi
---@param items ItemStock
local function loadIntoShulker(TurtleApi, items)
    repeat
        local loadedItem = false

        for slot = 1, TurtleApi.size() do
            local item = TurtleApi.getStack(slot)

            if item and items[item.name] and item.name ~= ItemApi.shulkerBox then
                if TurtleApi.loadIntoShulker(slot) then
                    loadedItem = true
                    break
                end
            end
        end
    until not loadedItem
end

---@param TurtleApi TurtleApi
---@param items ItemStock
---@param open ItemStock
local function requireItemsInShulkers(TurtleApi, items, open)
    local searchableList = SearchableList.new(open, "Required Items")

    EventLoop.waitForAny(function()
        while true do
            searchableList:run()
        end
    end, function()
        while true do
            open = getOpen(TurtleApi, items, true)

            if not open[ItemApi.shulkerBox] then
                loadIntoShulker(TurtleApi, items)
            end

            -- put shulkers into first slots to move them out of the last 4 slots in case items are required via the storage system
            -- and more than 4x shulkers are needed (last 4x slots are the I/O slots the storage has access to)
            TurtleApi.condense()

            if Utils.isEmpty(open) then
                break
            end

            searchableList:setOptions(getOptions(open))

            while true do
                local event = EventLoop.pull()

                if event == "turtle_inventory" or event == "peripheral" or event == "peripheral_detach" then
                    break
                end
            end
        end
    end)

    TurtleApi.digShulkers()
    TurtleApi.condense()
    term.clear()
    term.setCursorPos(1, 1)
end

---@param TurtleApi TurtleApi
---@param items ItemStock
---@param alwaysUseShulkers? boolean
return function(TurtleApi, items, alwaysUseShulkers)
    if items[ItemApi.shulkerBox] then
        -- making this work is more difficult than expected
        error("requiring shulker boxes is not supported")
    end

    local open, requiredShulkers = getOpen(TurtleApi, items, alwaysUseShulkers)

    if Utils.isEmpty(open) then
        TurtleApi.digShulkers()
        TurtleApi.condense()
        return
    elseif requiredShulkers > 0 or alwaysUseShulkers then
        requireItemsInShulkers(TurtleApi, items, open)
    else
        requireItemsInInventory(TurtleApi, items, open)
    end
end
