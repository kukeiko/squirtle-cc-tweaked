local Utils = require "lib.common.utils"
local EventLoop = require "lib.common.event-loop"
local Inventory = require "lib.inventory.inventory"
local InventoryReader = require "lib.inventory.inventory-reader"
local InventoryCollection = require "lib.inventory.inventory-collection"
local moveItem = require "lib.inventory.move-item"

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

---@return string[]
function InventoryApi.getAll()
    return Utils.map(InventoryCollection.getAll(), function(item)
        return item.name
    end)
end

---@param type InventoryType
---@param refresh boolean?
---@return string[]
function InventoryApi.getByType(type, refresh)
    local inventories = InventoryCollection.getByType(type)

    if refresh then
        -- print("[refresh]", table.concat(inventories))
        InventoryCollection.refresh(inventories)
    end

    return inventories
end

---@param name string
---@param slotTag InventorySlotTag
---@return integer
function InventoryApi.getSlotCount(name, slotTag)
    return InventoryCollection.getSlotCount(name, slotTag)
end

---@param inventoryType InventoryType
---@param label string
---@return string?
function InventoryApi.findByTypeAndLabel(inventoryType, label)
    local inventory = InventoryCollection.findByTypeAndLabel(inventoryType, label)

    if inventory then
        return inventory.name
    end
end

---@param name string
---@return integer
function InventoryApi.getItemsStock(name)
    ---@type integer
    local stock = 0
    local inventory = InventoryCollection.get(name)

    for index in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if stack then
            stock = stock + stack.count
        end
    end

    return stock
end

---@param tag InventorySlotTag
---@return ItemStock
function InventoryApi.getStockByTag(tag)
    return InventoryCollection.getStockByTag(tag)
end

---@param name string
---@param tag InventorySlotTag
---@param refresh? boolean
---@return ItemStock
function InventoryApi.getInventoryStockByTag(name, tag, refresh)
    return InventoryCollection.getInventoryStockByTag(name, tag, refresh)
end

---@param inventoryType InventoryType
---@param slotTag InventorySlotTag
---@return ItemStock
function InventoryApi.getStockByInventoryTypeAndTag(inventoryType, slotTag)
    return InventoryCollection.getStockByInventoryTypeAndTag(inventoryType, slotTag)
end

---@param name string
---@param tag InventorySlotTag
---@return ItemStock
function InventoryApi.getMaxStockByTag(name, tag)
    ---@type ItemStock
    local stock = {}
    local inventory = InventoryCollection.get(name)

    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if stack and slot.tags[tag] then
            stock[stack.name] = (stock[stack.name] or 0) + stack.maxCount
        end
    end

    return stock
end

---@param name string
---@param tag InventorySlotTag
---@param item string
---@return integer
function InventoryApi.getItemStockByTag(name, tag, item)
    local stock = 0
    local inventory = InventoryCollection.get(name)

    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if stack and stack.name == item and slot.tags[tag] then
            stock = stock + stack.count
        end
    end

    return stock
end

---@param name string
---@param tag InventorySlotTag
---@param item string
---@return integer
function InventoryApi.getItemMaxStockByTag(name, tag, item)
    local maxStock = 0
    local inventory = InventoryCollection.get(name)

    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if stack and stack.name == item and slot.tags[tag] then
            maxStock = maxStock + stack.maxCount
        end
    end

    return maxStock
end

---@param name string
---@param tag InventorySlotTag
---@param item string
---@return integer
function InventoryApi.getItemOpenStockByTag(name, tag, item)
    local stock = InventoryApi.getItemStockByTag(name, tag, item)
    local maxStock = InventoryApi.getItemMaxStockByTag(name, tag, item)

    return maxStock - stock
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return ItemStock
function InventoryApi.getStockByTagMultiInventory(inventories, tag)
    local totalStock = {}

    for _, name in ipairs(inventories) do
        local stock = InventoryCollection.getInventoryStockByTag(name, tag)

        for item, itemStock in pairs(stock) do
            totalStock[item] = (totalStock[item] or 0) + itemStock
        end
    end

    return totalStock
end

---@param name string
---@param slot integer
---@return ItemStack?
function InventoryApi.getStack(name, slot)
    return InventoryCollection.get(name).stacks[slot]
end

---@param name string
---@return table<integer, ItemStack>
function InventoryApi.getStacks(name)
    return InventoryCollection.get(name).stacks
end

---@param name string
---@param slot integer
---@param stack? ItemStack
function InventoryApi.setStack(name, slot, stack)
    InventoryCollection.get(name).stacks[slot] = stack
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
---@return ItemStock transferredTotal, ItemStock open
function InventoryApi.transferItems(from, fromTag, to, toTag, items, options)
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

    return transferredTotal, open
end

---@param from string[]
---@param fromTag InventorySlotTag
---@param to string[]
---@param toTag InventorySlotTag
---@param items? ItemStock
---@param options? TransferOptions
---@return ItemStock transferredTotal, ItemStock open
function InventoryApi.transfer(from, fromTag, to, toTag, items, options)
    -- [todo] this feels a bit hacky, but is required for performance.
    if not items then
        local fromStock = InventoryApi.getStockByTagMultiInventory(from, fromTag)
        ---@type ItemStock
        local filteredFromStock = {}

        if Utils.find(to, function(name)
            return InventoryCollection.get(name).allowAllocate
        end) then
            filteredFromStock = fromStock
        else
            local toStock = InventoryApi.getStockByTagMultiInventory(to, toTag)

            for item, quantity in pairs(fromStock) do
                if toStock[item] then
                    filteredFromStock[item] = quantity
                end
            end
        end

        items = filteredFromStock
    end

    return InventoryApi.transferItems(from, fromTag, to, toTag, items, options)
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
    EventLoop.queue("inventory:stop")
end

return InventoryApi
