local InventoryApi = require "inventory"
local InventoryPeripheral = require "inventory.inventory-peripheral"

---@class StorageService : Service
local StorageService = {name = "storage"}

---@param stashLabel string
---@param itemStock ItemStock
---@return ItemStock
function StorageService.transferStockToStash(stashLabel, itemStock)
    local stash = InventoryApi.findInventoryByTypeAndLabel("stash", stashLabel)

    if not stash then
        error(string.format("stash %s doesn't exist", stashLabel))
    end

    return InventoryApi.distributeItems(InventoryApi.getInventories(), {stash}, itemStock, "withdraw", "input")
end

---@param stashLabel string
---@param item string
---@param total integer
---@return integer
function StorageService.transferItemToStash(stashLabel, item, total)
    local transferred = StorageService.transferStockToStash(stashLabel, {[item] = total})

    return transferred[item] or 0
end

---@return ItemStock
function StorageService.getStock()
    return InventoryApi.getStockByTag("withdraw")
end

function StorageService.getItemDisplayNames()
    return InventoryPeripheral.getItemDisplayNames()
end

return StorageService
