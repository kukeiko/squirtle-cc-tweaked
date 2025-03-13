local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ItemStock = require "lib.models.item-stock"
local Inventory = require "lib.models.inventory"
local InventoryReader = require "lib.apis.inventory.inventory-reader"
local InventoryLocks = require "lib.apis.inventory.inventory-locks"

---@class InventoryCollection
---@field useCache boolean
local InventoryCollection = {useCache = false}

---@type table<string, Inventory>
local cache = {}

function InventoryCollection.clear()
    cache = {}
end

---@param inventory string
---@return Inventory
function InventoryCollection.get(inventory)
    if not InventoryCollection.useCache then
        return InventoryReader.read(inventory)
    elseif not cache[inventory] then
        InventoryCollection.mount({inventory})
    end

    return cache[inventory]
end

---@param inventories string[]
---@return Inventory[]
function InventoryCollection.resolve(inventories)
    return Utils.map(inventories, function(inventory)
        return InventoryCollection.get(inventory)
    end)
end

---@return Inventory[]
function InventoryCollection.getAll()
    return Utils.map(cache, function(inventory)
        return inventory
    end)
end

---@param type InventoryType
---@return Inventory[]
function InventoryCollection.getByType(type)
    return Utils.filterMapProjectList(cache, function(item)
        return item.type == type
    end, function(item)
        return item
    end)
end

---@param inventoryType InventoryType
---@param label string
---@return Inventory
function InventoryCollection.getByTypeAndLabel(inventoryType, label)
    for _, inventory in pairs(cache) do
        if inventory.type == inventoryType and inventory.label == label then
            return inventory
        end
    end

    error(string.format("inventory w/ type %s and label %s doesn't exist", inventoryType, label))
end

---@param inventories string[]
---@param expected? InventoryType
function InventoryCollection.mount(inventories, expected)
    for _, inventory in pairs(inventories) do
        cache[inventory] = InventoryReader.read(inventory, expected)
    end
end

---@param inventories string[]
function InventoryCollection.unmount(inventories)
    for _, inventory in pairs(inventories) do
        cache[inventory] = nil
    end
end

---@param name string
---@return boolean
function InventoryCollection.isMounted(name)
    if InventoryCollection.useCache then
        return cache[name] ~= nil
    else
        -- [todo] meh
        return peripheral.isPresent(name)
    end
end

---@param inventories string[]
function InventoryCollection.refresh(inventories)
    local fns = Utils.map(inventories, function(inventory)
        return function()
            local lockSuccess, unlock = InventoryLocks.lock({inventory})

            if not lockSuccess then
                return
            end

            pcall(function()
                cache[inventory] = InventoryReader.read(inventory)
            end)
            unlock()
        end
    end)

    local chunkedFns = Utils.chunk(fns, 32)

    for i, chunk in pairs(chunkedFns) do
        EventLoop.run(table.unpack(chunk))

        if i < #chunkedFns then
            os.sleep(1)
        end
    end
end

---@param inventories string[]
---@param item string
---@param tag InventorySlotTag
---@return integer
function InventoryCollection.getItemCount(inventories, item, tag)
    return Utils.sum(InventoryCollection.resolve(inventories), function(inventory)
        return Inventory.getItemCount(inventory, item, tag)
    end)
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return integer
function InventoryCollection.getTotalItemCount(inventories, tag)
    return Utils.sum(InventoryCollection.resolve(inventories), function(inventory)
        return Inventory.getTotalItemCount(inventory, tag)
    end)
end

---@param inventories string[]
---@param item string
---@param tag InventorySlotTag
---@return integer
function InventoryCollection.getItemMaxCount(inventories, item, tag)
    return Utils.sum(InventoryCollection.resolve(inventories), function(inventory)
        return Inventory.getItemMaxCount(inventory, item, tag)
    end)
end

---@param inventories string[]
---@param item string
---@param tag InventorySlotTag
---@return integer
function InventoryCollection.getItemOpenCount(inventories, item, tag)
    return Utils.sum(InventoryCollection.resolve(inventories), function(inventory)
        return Inventory.getItemOpenCount(inventory, item, tag)
    end)
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return integer
function InventoryCollection.getSlotCount(inventories, tag)
    return Utils.sum(InventoryCollection.resolve(inventories), function(inventory)
        return Inventory.getSlotCount(inventory, tag)
    end)
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return ItemStock
function InventoryCollection.getStock(inventories, tag)
    local stocks = Utils.map(InventoryCollection.resolve(inventories), function(inventory)
        return Inventory.getStock(inventory, tag)
    end)

    return ItemStock.merge(stocks)
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return ItemStock
function InventoryCollection.getMaxStock(inventories, tag)
    local stocks = Utils.map(InventoryCollection.resolve(inventories), function(inventory)
        return Inventory.getMaxStock(inventory, tag)
    end)

    return ItemStock.merge(stocks)
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return ItemStock
function InventoryCollection.getOpenStock(inventories, tag)
    local stocks = Utils.map(InventoryCollection.resolve(inventories), function(inventory)
        return Inventory.getOpenStock(inventory, tag)
    end)

    return ItemStock.merge(stocks)
end

return InventoryCollection
