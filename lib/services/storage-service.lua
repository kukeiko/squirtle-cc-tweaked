local InventoryApi = require "inventory"

---@class StorageService : Service
local StorageService = {name = "storage"}

function StorageService.foo()
    return "foo"
end

---@param stashLabel string
---@param itemStock ItemStock
---@return ItemStock
function StorageService.transferStockToStash(stashLabel, itemStock)
    local stash = InventoryApi.findInventoryByTypeAndLabel("stash", stashLabel)

    if not stash then
        error(string.format("stash %s doesn't exist", stashLabel))
    end

    local storages = InventoryApi.getInventories("storage")
    return InventoryApi.distributeItems(storages, {stash}, itemStock, "output", "input")
end

---@param stashLabel string
---@param item string
---@param total integer
---@return integer
function StorageService.transferItemToStash(stashLabel, item, total)
    local transferred = StorageService.transferStockToStash(stashLabel, {[item] = total})

    return transferred[item] or 0
end

return StorageService
