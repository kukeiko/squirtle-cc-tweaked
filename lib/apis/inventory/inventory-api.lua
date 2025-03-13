local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ItemStock = require "lib.models.item-stock"
local Inventory = require "lib.models.inventory"
local InventoryReader = require "lib.apis.inventory.inventory-reader"
local InventoryCollection = require "lib.apis.inventory.inventory-collection"
local InventoryLocks = require "lib.apis.inventory.inventory-locks"
local moveItem = require "lib.apis.inventory.move-item"

---@class InventoryApi
local InventoryApi = {}

---@param names string[]
---@param item string
---@param tag InventorySlotTag
---@return string[] candidates
local function getFromCandidates(names, item, tag)
    return Utils.filter(names, function(name)
        return InventoryCollection.isMounted(name) and Inventory.canProvideItem(InventoryCollection.get(name), item, tag)
    end)
end

---@param names string[]
---@param item string
---@param tag InventorySlotTag
---@return string[] candidates
local function getToCandidates(names, item, tag)
    return Utils.filter(names, function(name)
        return InventoryCollection.isMounted(name) and Inventory.canTakeItem(InventoryCollection.get(name), item, tag)
    end)
end

---@param type InventoryType
function InventoryApi.refresh(type)
    local inventories = InventoryApi.getByType(type)
    InventoryCollection.refresh(inventories)
end

---@param inventories string[]
function InventoryApi.refreshInventories(inventories)
    InventoryCollection.refresh(inventories)
end

---@return string[]
function InventoryApi.getAll()
    return Utils.map(InventoryCollection.getAll(), function(item)
        return item.name
    end)
end

---@param type InventoryType
---@return string[]
function InventoryApi.getByType(type)
    local inventories = InventoryCollection.getByType(type)

    return Utils.map(inventories, function(item)
        return item.name
    end)
end

---@param type InventoryType
---@return string[]
function InventoryApi.getRefreshedByType(type)
    InventoryApi.refresh(type)
    return InventoryApi.getByType(type)
end

---@param inventoryType InventoryType
---@param label string
---@return string
function InventoryApi.getByTypeAndLabel(inventoryType, label)
    return InventoryCollection.getByTypeAndLabel(inventoryType, label).name
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return integer
function InventoryApi.getSlotCount(inventories, tag)
    return InventoryCollection.getSlotCount(inventories, tag)
end

---@param inventories string[]
---@param item string
---@param tag InventorySlotTag
---@return integer
function InventoryApi.getItemCount(inventories, item, tag)
    return InventoryCollection.getItemCount(inventories, item, tag)
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return integer
function InventoryApi.getTotalItemCount(inventories, tag)
    return InventoryCollection.getTotalItemCount(inventories, tag)
end

---@param inventories string[]
---@param item string
---@param tag InventorySlotTag
---@return integer
function InventoryApi.getItemMaxCount(inventories, item, tag)
    return InventoryCollection.getItemMaxCount(inventories, item, tag)
end

---@param inventories string[]
---@param item string
---@param tag InventorySlotTag
---@return integer
function InventoryApi.getItemOpenCount(inventories, item, tag)
    return InventoryCollection.getItemOpenCount(inventories, item, tag)
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return ItemStock
function InventoryApi.getStock(inventories, tag)
    return InventoryCollection.getStock(inventories, tag)
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return ItemStock
function InventoryApi.getMaxStock(inventories, tag)
    return InventoryCollection.getMaxStock(inventories, tag)
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return ItemStock
function InventoryApi.getOpenStock(inventories, tag)
    return InventoryCollection.getOpenStock(inventories, tag)
end

---@param from string[]
---@param fromTag InventorySlotTag
---@param to string[]
---@param toTag InventorySlotTag
---@param item string
---@param quantity? integer
---@param options? TransferOptions
---@return integer transferredTotal
function InventoryApi.transferItem(from, fromTag, to, toTag, item, quantity, options)
    from = getFromCandidates(from, item, fromTag)
    to = getToCandidates(to, item, toTag)

    options = options or {}
    local total = quantity or InventoryCollection.getItemCount(from, item, fromTag)
    local totalTransferred = 0

    while totalTransferred < total and #from > 0 and #to > 0 do
        if #from == 1 and #to == 1 and from[1] == to[1] then
            break
        end

        local transferPerOutput = (total - totalTransferred)

        if not options.fromSequential then
            transferPerOutput = transferPerOutput / #from
        end

        local transferPerInput = math.max(1, math.floor(transferPerOutput))

        if not options.toSequential then
            transferPerInput = math.max(1, math.floor(transferPerOutput / #to))
        end

        --- [todo] in regards to locking/unlocking:
        --- previously, before the rewrite, we were sorting based on lock-state, i.e. take inventories first that are not locked.
        --- we really should have that functionality again to make sure the system is not super slow in some cases.
        --- I'm thinking of doing that logic exactly here, as I assume all future distribute() methods will make use of distributeItem().
        for _, fromName in ipairs(from) do
            for _, toName in ipairs(to) do
                if fromName ~= toName then
                    local transferred = moveItem(fromName, toName, item, fromTag, toTag, transferPerInput, options.rate)
                    totalTransferred = totalTransferred + transferred

                    if totalTransferred == total then
                        return totalTransferred
                    end
                end
            end
        end

        from = getFromCandidates(from, item, fromTag)
        to = getToCandidates(to, item, toTag)
    end

    return totalTransferred
end

---@param from string[]
---@param fromTag InventorySlotTag
---@param to string[]
---@param toTag InventorySlotTag
---@param items ItemStock
---@param options? TransferOptions
---@return boolean success, ItemStock transferred, ItemStock open
function InventoryApi.transfer(from, fromTag, to, toTag, items, options)
    ---@type ItemStock
    local transferredTotal = {}
    ---@type ItemStock
    local open = {}

    for item, quantity in pairs(items) do
        local transferred = InventoryApi.transferItem(from, fromTag, to, toTag, item, quantity, options)

        if transferred > 0 then
            transferredTotal[item] = transferred

            if transferred < quantity then
                open[item] = quantity - transferred
            end
        else
            open[item] = quantity
        end
    end

    return Utils.isEmpty(open), transferredTotal, open
end

---@param from string[]
---@param fromTag InventorySlotTag
---@param to string[]
---@param toTag InventorySlotTag
---@param options? TransferOptions
---@return boolean success, ItemStock transferred, ItemStock open
function InventoryApi.restock(from, fromTag, to, toTag, options)
    local fromStock = InventoryApi.getStock(from, fromTag)
    local openStock = InventoryApi.getOpenStock(to, toTag)
    ---@type ItemStock
    local filteredOpenStock = {}

    for item in pairs(fromStock) do
        filteredOpenStock[item] = openStock[item]
    end

    return InventoryApi.transfer(from, fromTag, to, toTag, filteredOpenStock, options)
end

---@param from string[]
---@param fromTag InventorySlotTag
---@param to string[]
---@param toTag InventorySlotTag
---@param options? TransferOptions
---@return boolean success, ItemStock transferred, ItemStock open
function InventoryApi.empty(from, fromTag, to, toTag, options)
    ---@type ItemStock
    local emptyableStock = {}
    local fromStock = InventoryApi.getStock(from, fromTag)

    to = Utils.filter(to, function(to)
        if not InventoryCollection.isMounted(to) then
            return false
        end

        local inventory = InventoryCollection.get(to)

        for item, quantity in pairs(fromStock) do
            if Inventory.canTakeItem(inventory, item, toTag) then
                emptyableStock[item] = quantity
                return true
            end
        end

        return false
    end)

    return InventoryApi.transfer(from, fromTag, to, toTag, emptyableStock, options)
end

---@param from string[]
---@param fromTag InventorySlotTag
---@param to string[]
---@param toTag InventorySlotTag
---@param stock ItemStock
---@param options? TransferOptions
---@return boolean success, ItemStock transferred, ItemStock open
function InventoryApi.fulfill(from, fromTag, to, toTag, stock, options)
    local lockSuccess, unlock = InventoryLocks.lock(to)

    if not lockSuccess then
        return false, {}, {}
    end

    local open = ItemStock.subtract(stock, InventoryApi.getStock(to, toTag))
    local transferSuccess, transferred, open = InventoryApi.transfer(from, fromTag, to, toTag, open, options)
    unlock()

    return transferSuccess, transferred, open
end

local function onPeripheralEventMountInventory()
    while true do
        EventLoop.pull("peripheral", function(_, name)
            if InventoryReader.isInventoryType(name) then
                InventoryCollection.mount({name})
            end
        end)
    end
end

---@param flag boolean
function InventoryApi.useCache(flag)
    InventoryCollection.useCache = flag
end

function InventoryApi.discover()
    print("[inventory] mounting connected inventories...")
    ---@type string[]
    local names = peripheral.getNames()

    local mountFns = Utils.map(names, function(name)
        return function()
            if InventoryReader.isInventoryType(name) then
                InventoryCollection.mount({name})
            end
        end
    end)

    local chunkSize = 64
    local chunkedMountFns = Utils.chunk(mountFns, chunkSize)
    local x, y = Utils.printProgress(0, #chunkedMountFns)

    for i, chunk in pairs(chunkedMountFns) do
        EventLoop.run(table.unpack(chunk))
        x, y = Utils.printProgress(i, #chunkedMountFns, x, y)
    end
end

--- Runs the process of automatically mounting/unmounting any attached inventories until stopped.
--- Call "Inventory.stop()" inside another coroutine to stop.
function InventoryApi.start()
    EventLoop.runUntil("inventory:stop", function()
        onPeripheralEventMountInventory()
    end, function()
        while true do
            EventLoop.pull("peripheral_detach", function(_, name)
                if InventoryCollection.isMounted(name) then
                    print("[unmount]", name)
                    InventoryCollection.unmount({name})
                end
            end)
        end
    end)
end

function InventoryApi.stop()
    InventoryCollection.clear()
    InventoryLocks.clear()
    EventLoop.queue("inventory:stop")
end

return InventoryApi
