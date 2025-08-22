local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local SearchableList = require "lib.ui.searchable-list"
local InventoryLocks = require "lib.apis.inventory.inventory-locks"
local InventoryCollection = require "lib.apis.inventory.inventory-collection"

---@return SearchableListOption[]
local function getActiveUnlockList()
    local options = Utils.map(InventoryLocks.getInventoriesPendingUnlock(), function(inventory)
        ---@type SearchableListOption
        local option = {id = inventory, name = inventory, suffix = InventoryCollection.getType(inventory)}

        return option
    end)

    return options
end

---@param shellWindow ShellWindow
return function(shellWindow)
    local list = SearchableList.new(getActiveUnlockList(), "Active Unocks")

    EventLoop.run(function()
        while true do
            list:run()
        end
    end, function()
        while true do
            shellWindow:pullIsVisible()
            list:setOptions(getActiveUnlockList())
            shellWindow:runUntilInvisible(function()
                while true do
                    InventoryLocks.pullLockChange()
                    list:setOptions(getActiveUnlockList())
                end
            end)
        end
    end)
end
