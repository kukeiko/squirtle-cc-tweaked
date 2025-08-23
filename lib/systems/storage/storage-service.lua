local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local DatabaseService = require "lib.systems.database.database-service"
local ItemApi = require "lib.apis.item-api"
local CraftingApi = require "lib.apis.crafting-api"
local InventoryApi = require "lib.apis.inventory.inventory-api"

---@class StorageService : Service
local StorageService = {name = "storage"}

---@param storedStock ItemStock
---@return CraftingRecipes
local function getCraftingRecipes(storedStock)
    local recipes = Rpc.nearest(DatabaseService).getCraftingRecipes()

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

    return recipes
end

---@return CraftingRecipes
function StorageService.getCraftingRecipes()
    local storedStock = StorageService.getStock()
    return getCraftingRecipes(storedStock)
end

---@param type InventoryType
---@return string[]
function StorageService.getByType(type)
    return InventoryApi.getByType(type)
end

---@param handle InventoryHandle
function StorageService.refresh(handle)
    InventoryApi.refreshInventories(handle)
end

---@param inventory InventoryHandle
function StorageService.mount(inventory)
    InventoryApi.mount(inventory)
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param stock ItemStock
---@return boolean success, ItemStock transferred, ItemStock open
function StorageService.transfer(from, to, stock)
    return InventoryApi.transfer(from, to, stock)
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param options? TransferOptions
---@return boolean success, ItemStock transferred, ItemStock open
function StorageService.restock(from, to, options)
    return InventoryApi.restock(from, to, options)
end

---@param from InventoryHandle
---@param to InventoryHandle
---@return boolean success, ItemStock transferred, ItemStock open
function StorageService.empty(from, to)
    return InventoryApi.empty(from, to)
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param stock ItemStock
---@return boolean success, ItemStock transferred, ItemStock open
function StorageService.fulfill(from, to, stock)
    return InventoryApi.fulfill(from, to, stock)
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param stock ItemStock
---@return boolean success, ItemStock transferred, ItemStock open
function StorageService.keep(from, to, stock)
    return InventoryApi.keep(from, to, stock)
end

---@param item string
---@return integer
function StorageService.getItemCount(item)
    local storages = InventoryApi.getByType("storage")
    return InventoryApi.getItemCount(storages, item, "withdraw")
end

---@return ItemStock
function StorageService.getStock()
    local storages = InventoryApi.getByType("storage")
    return InventoryApi.getStock(storages, "withdraw")
end

---@return ItemStock
function StorageService.getOpenStock()
    local storages = InventoryApi.getByType("storage")
    return InventoryApi.getOpenStock(storages, "withdraw")
end

---@return ItemStock
function StorageService.getMaxStock()
    local storages = InventoryApi.getByType("storage")
    return InventoryApi.getMaxStock(storages, "withdraw")
end

---@param name string
---@param tag InventorySlotTag
---@return ItemStock
function StorageService.getStockByName(name, tag)
    return InventoryApi.getStock({name}, tag)
end

---@param item string
---@return integer?
function StorageService.getCraftableCount(item)
    local storedStock = StorageService.getStock()
    local recipes = getCraftingRecipes(storedStock)

    if not recipes[item] then
        return nil
    end

    return CraftingApi.getCraftableCount(item, storedStock, recipes)
end

---Returns all items that could be crafted and how many of those we could craft.
---Recipes for which the ItemDetails are not known (either of the crafted item or any of its ingredients) are omitted.
---@return ItemStock
function StorageService.getCraftableStock()
    local storedStock = StorageService.getStock()
    local recipes = getCraftingRecipes(storedStock)
    local craftableStock = {}

    for item in pairs(recipes) do
        craftableStock[item] = CraftingApi.getCraftableCount(item, storedStock, recipes)
    end

    return craftableStock
end

---@return ItemDetails
function StorageService.getItemDetails()
    return ItemApi.getItemDetails()
end

---@param stock ItemStock
---@return integer
function StorageService.getRequiredSlotCount(stock)
    return ItemApi.getRequiredSlotCount(stock)
end

---@param taskId integer
---@param slotCount? integer
---@return integer
function StorageService.allocateTaskBuffer(taskId, slotCount)
    return InventoryApi.allocateTaskBuffer(taskId, slotCount)
end

---@param taskId integer
---@param stock ItemStock
---@return integer
function StorageService.allocateTaskBufferForStock(taskId, stock)
    local slotCount = StorageService.getRequiredSlotCount(stock)
    return InventoryApi.allocateTaskBuffer(taskId, slotCount)
end

---[todo] ❌ to be replaced by a more generic method that accepts InventoryHandle
---@param bufferId integer
---@return ItemStock
function StorageService.getBufferStock(bufferId)
    return InventoryApi.getBufferStock(bufferId)
end

---@param bufferId integer
---@param to? InventoryHandle
function StorageService.flushAndFreeBuffer(bufferId, to)
    InventoryApi.flushAndFreeBuffer(bufferId, to)
end

return StorageService
