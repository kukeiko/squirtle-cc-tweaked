local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local DatabaseService = require "lib.common.database-service"
local CraftingApi = require "lib.common.crafting-api"
local InventoryApi = require "lib.inventory.inventory-api"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local TaskBufferService = require "lib.common.task-buffer-service"

---@class StorageService : Service
local StorageService = {name = "storage"}

---@param type InventoryType
---@return string[]
function StorageService.getByType(type)
    return InventoryApi.getByType(type)
end

---@param stashLabel string
function StorageService.getStashName(stashLabel)
    return InventoryApi.getByTypeAndLabel("stash", stashLabel)
end

-- [todo] a hack I had to introduce so the crafter turtle could tell storage that its stash changed
---@param inventories string[]
function StorageService.refreshInventories(inventories)
    InventoryApi.refreshInventories(inventories)
end

---@param from string[]
---@param fromTag InventorySlotTag
---@param to string[]
---@param toTag InventorySlotTag
---@param items? ItemStock
---@param options? TransferOptions
---@return ItemStock transferredTotal, ItemStock open
function StorageService.transfer(from, fromTag, to, toTag, items, options)
    return InventoryApi.transfer(from, fromTag, to, toTag, items, options)
end

---@param stashLabel string
---@param itemStock ItemStock
---@return ItemStock, ItemStock open
function StorageService.transferStockToStash(stashLabel, itemStock)
    local stash = StorageService.getStashName(stashLabel)
    return InventoryApi.transferItems(InventoryApi.getAll(), "withdraw", {stash}, "input", itemStock)
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
    local storages = InventoryApi.getByType("storage")
    return InventoryApi.getStock(storages, "withdraw")
end

---Returns all items that could be crafted and how many of those we could craft.
---Recipes for which the ItemDetails are not known (either of the crafted item or any of its ingredients) are omitted.
---@return ItemStock
function StorageService.getCraftableStock()
    local recipes = Rpc.nearest(DatabaseService).getCraftingRecipes()
    local storedStock = StorageService.getStock()

    -- only keep recipes where the item itself or all of its ingredients are known to the storage service,
    -- otherwise we don't have the maxCount of the item(s) required for allocating buffers (or any other
    -- logic requiring calculating required slot count based on ingredients)
    recipes = Utils.filterMap(recipes, function(recipe)
        if not storedStock[recipe.item] then
            return false
        end

        local ingredients = CraftingApi.getIngredients(recipe, recipes)

        return Utils.every(ingredients, function(ingredient)
            return storedStock[ingredient] ~= nil
        end)
    end)

    local craftableStock = {}

    for item in pairs(recipes) do
        craftableStock[item] = CraftingApi.getCraftableCount(item, storedStock, recipes)
    end

    return craftableStock
end

function StorageService.getItemDetails()
    return InventoryPeripheral.getItemDetails()
end

---@param stock ItemStock
---@return integer
function StorageService.getRequiredSlotCount(stock)
    local slotCount = 0

    for item, quantity in pairs(stock) do
        slotCount = slotCount + math.ceil(quantity / InventoryPeripheral.getItemMaxCount(item))
    end

    return slotCount
end

-- [todo] all buffer related methods have been copied to TaskBufferService
---@param task Task
---@param slotCount integer
---@return integer
function StorageService.allocateTaskBuffer(task, slotCount)
    return TaskBufferService.allocateTaskBuffer(task.id, slotCount)
end

---@param bufferId integer
function StorageService.freeBuffer(bufferId)
    TaskBufferService.freeBuffer(bufferId)
end

---@param bufferId integer
function StorageService.flushBuffer(bufferId)
    TaskBufferService.flushBuffer(bufferId)
end

---@param bufferId integer
---@param fromType? InventoryType
---@param fromTag? InventorySlotTag
---@param itemStock ItemStock
function StorageService.transferStockToBuffer(bufferId, itemStock, fromType, fromTag)
    TaskBufferService.transferStockToBuffer(bufferId, itemStock, fromType, fromTag)
end

---@param bufferId integer
---@param from string
---@param fromTag InventorySlotTag
function StorageService.transferInventoryStockToBuffer(bufferId, from, fromTag)
    TaskBufferService.transferInventoryStockToBuffer(bufferId, from, fromTag)
end

---@param bufferId integer
---@return string[]
function StorageService.getBufferNames(bufferId)
    return TaskBufferService.getBufferNames(bufferId)
end

---@param bufferId integer
---@return ItemStock
function StorageService.getBufferStock(bufferId)
    return TaskBufferService.getBufferStock(bufferId)
end

---@param bufferId integer
---@param to string[]
---@param toTag InventorySlotTag
---@param stock? ItemStock
---@return ItemStock, ItemStock open
function StorageService.transferBufferStock(bufferId, to, toTag, stock)
    return TaskBufferService.transferBufferStock(bufferId, to, toTag, stock)
end

return StorageService
