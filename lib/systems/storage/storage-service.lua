local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local DatabaseService = require "lib.systems.database.database-service"
local CraftingApi = require "lib.apis.crafting-api"
local InventoryApi = require "lib.apis.inventory.inventory-api"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local TaskBufferApi = require "lib.apis.inventory.task-buffer-api"

---@class StorageService : Service
local StorageService = {name = "storage"}

---@param type InventoryType
---@return string[]
function StorageService.getByType(type)
    return InventoryApi.getByType(type)
end

---@param handle InventoryHandle
---@return boolean
local function isBufferHandle(handle)
    return type(handle) == "number"
end

---@param handle InventoryHandle
---@return InventoryType?
local function getTypeByHandle(handle)
    if type(handle) == "number" then
        return "buffer"
    elseif type(handle) == "string" then
        return "stash"
    end

    return nil
end

---@param handle InventoryHandle
---@return string[]
local function resolveHandle(handle)
    if type(handle) == "number" then
        return TaskBufferApi.resolveBuffer(handle)
    elseif type(handle) == "string" then
        return {InventoryApi.getByTypeAndLabel("stash", handle)}
    else
        return handle --[[@as table<string>]]
    end
end

---@param type InventoryType?
---@return InventorySlotTag
local function getDefaultFromSlotTag(type)
    if type == "buffer" or type == "stash" then
        return "buffer"
    end

    return "output"
end

---@param type InventoryType?
---@return InventorySlotTag
local function getDefaultToSlotTag(type)
    if type == "buffer" or type == "stash" then
        return "buffer"
    end

    return "input"
end

---@param type InventoryType?
---@param options TransferOptions
---@return TransferOptions
local function getDefaultFromOptions(type, options)
    if type == "buffer" and options.fromSequential == nil then
        options.fromSequential = true
    end

    return options
end

---@param type InventoryType?
---@param options TransferOptions
---@return TransferOptions
local function getDefaultToOptions(type, options)
    if type == "buffer" and options.toSequential == nil then
        options.toSequential = true
    end

    return options
end

---@param handle InventoryHandle
---@param options? TransferOptions
---@return string[] inventories, InventorySlotTag tag, TransferOptions options
local function getFromHandleTransferArguments(handle, options)
    local type = getTypeByHandle(handle)
    local inventories = resolveHandle(handle)
    local tag = getDefaultFromSlotTag(type)
    local options = getDefaultFromOptions(type, options or {})

    return inventories, tag, options
end

---@param handle InventoryHandle
---@---@param options? TransferOptions
---@return string[] inventories, InventorySlotTag tag, TransferOptions options
local function getToHandleTransferArguments(handle, options)
    local type = getTypeByHandle(handle)
    local inventories = resolveHandle(handle)
    local tag = getDefaultToSlotTag(type)
    local options = getDefaultToOptions(type, options or {})

    return inventories, tag, options
end

---@param handle InventoryHandle
function StorageService.refresh(handle)
    InventoryApi.refreshInventories(resolveHandle(handle))
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param stock ItemStock
---@return boolean success, ItemStock transferred, ItemStock open
function StorageService.transfer(from, to, stock)
    local fromInventories, fromTag, options = getFromHandleTransferArguments(from)
    local toInventories, toTag, options = getToHandleTransferArguments(to, options)

    if isBufferHandle(to) then
        local bufferId = to --[[@as integer]]
        TaskBufferApi.resizeByStock(bufferId, stock)
    end

    return InventoryApi.transfer(fromInventories, fromTag, toInventories, toTag, stock, options)
end

---@param from string[]
---@param fromTag InventorySlotTag
---@param to string[]
---@param toTag InventorySlotTag
---@param options? TransferOptions
---@return boolean success, ItemStock transferred, ItemStock open
function StorageService.restock(from, fromTag, to, toTag, options)
    return InventoryApi.restock(from, fromTag, to, toTag, options)
end

---@param from InventoryHandle
---@param to InventoryHandle
---@return boolean success, ItemStock transferred, ItemStock open
function StorageService.empty(from, to)
    local fromInventories, fromTag, options = getFromHandleTransferArguments(from)
    local toInventories, toTag, options = getToHandleTransferArguments(to, options)

    if isBufferHandle(to) then
        -- [todo] duplicate logic, InventoryApi is also reading the stock like this.
        -- maybe a sign that we should move this logic to InventoryApi.
        local fromStock = InventoryApi.getStock(fromInventories, fromTag)
        local bufferId = to --[[@as integer]]
        TaskBufferApi.resizeByStock(bufferId, fromStock)
    end

    return InventoryApi.empty(fromInventories, fromTag, toInventories, toTag, options)
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param stock ItemStock
---@return boolean success, ItemStock transferred, ItemStock open
function StorageService.fulfill(from, to, stock)
    local fromInventories, fromTag, options = getFromHandleTransferArguments(from)
    local toInventories, toTag, options = getToHandleTransferArguments(to, options)

    if isBufferHandle(to) then
        local bufferId = to --[[@as integer]]
        TaskBufferApi.resizeByStock(bufferId, stock)
    end

    return InventoryApi.fulfill(fromInventories, fromTag, toInventories, toTag, stock, options)
end

---@return ItemStock
function StorageService.getStock()
    local storages = InventoryApi.getByType("storage")
    return InventoryApi.getStock(storages, "withdraw")
end

---@param name string
---@param tag InventorySlotTag
function StorageService.getStockByName(name, tag)
    return InventoryApi.getStock({name}, tag)
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
    return InventoryPeripheral.getRequiredSlotCount(stock)
end

---@param taskId integer
---@param slotCount? integer
---@return integer
function StorageService.allocateTaskBuffer(taskId, slotCount)
    return TaskBufferApi.allocateTaskBuffer(taskId, slotCount)
end

---@param bufferId integer
---@return ItemStock
function StorageService.getBufferStock(bufferId)
    return TaskBufferApi.getBufferStock(bufferId)
end

---@param bufferId integer
function StorageService.flushAndFreeBuffer(bufferId)
    TaskBufferApi.flushBuffer(bufferId)
    TaskBufferApi.freeBuffer(bufferId)
end

return StorageService
