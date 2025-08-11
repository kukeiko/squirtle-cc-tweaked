local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ItemStock = require "lib.models.item-stock"
local ItemApi = require "lib.apis.item-api"
local SearchableList = require "lib.ui.searchable-list"

local defaultItemMaxCount = 64
local maxCarriedShulkers = 8

---@param TurtleApi TurtleApi
---@param items ItemStock
---@param alwaysUseShulkers? boolean
---@return ItemStock, integer
local function getOpen(TurtleApi, items, alwaysUseShulkers)
    local open = ItemStock.subtract(items, TurtleApi.getStock(true))

    if not alwaysUseShulkers and ItemApi.getRequiredSlotCount(open, defaultItemMaxCount) <= TurtleApi.numEmptySlots() then
        -- the additionally required items fit into the inventory
        return open, 0
    end

    -- the additionally required items don't fit into inventory or the user wants them to put into shulkers,
    -- so we'll calculate the number of required shulkers based on the items that already exist in inventory
    -- and the items that are still needed.
    local takenInventoryStock = ItemStock.intersect(TurtleApi.getStock(), items)
    local requiredShulkers = TurtleApi.getRequiredAdditionalShulkers(ItemStock.merge({open, takenInventoryStock}))

    if requiredShulkers > maxCarriedShulkers then
        -- [todo] ❌ hacky way of ensuring that the turtle has enough space to carry all the shulkers, as we are
        -- missing logic to figure out how many empty slots we'll have taking into account items in the inventory
        -- which will not be put into shulkers.
        error(string.format("trying to require %d shulkers (max allowed: %d)", requiredShulkers, maxCarriedShulkers))
    elseif requiredShulkers > 0 then
        return {[ItemApi.shulkerBox] = requiredShulkers}, requiredShulkers
    else
        return open, 0
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
    term.clear()
    term.setCursorPos(1, 1)
end

---@param TurtleApi TurtleApi
---@param items ItemStock
---@param alwaysUseShulkers? boolean
return function(TurtleApi, items, alwaysUseShulkers)
    local open, requiredShulkers = getOpen(TurtleApi, items, alwaysUseShulkers)

    if Utils.isEmpty(open) then
        return
    elseif requiredShulkers > 0 or alwaysUseShulkers then
        requireItemsInShulkers(TurtleApi, items, open)
    else
        requireItemsInInventory(TurtleApi, items, open)
    end
end
