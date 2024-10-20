local Utils = require "lib.common.utils"
local EventLoop = require "lib.common.event-loop"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local InventoryReader = require "lib.inventory.inventory-reader"
local InventoryCollection = require "lib.inventory.inventory-collection"

---@class InventoryApi
local Inventory = {}

---@param names string[]
---@param item string
---@param tag InventorySlotTag
---@return string[] candidates
local function getFromCandidates(names, item, tag)
    return Utils.filter(names, function(name)
        return InventoryCollection.isMounted(name) and Inventory.canProvideItem(name, item, tag)
    end)
end

---@param names string[]
---@param item string
---@param tag InventorySlotTag
---@return string[] candidates
local function getToCandidates(names, item, tag)
    return Utils.filter(names, function(name)
        return InventoryCollection.isMounted(name) and Inventory.canTakeItem(name, item, tag)
    end)
end

---@param names string[]
function Inventory.refresh(names)
    return InventoryCollection.refreshMany(names)
end

---@param type InventoryType
function Inventory.refreshByType(type)
    return InventoryCollection.refreshByType(type)
end

---@param type InventoryType?
---@param refresh boolean?
---@return string[]
function Inventory.getInventories(type, refresh)
    return InventoryCollection.getInventories(type, refresh)
end

---@param name string
---@param slotTag InventorySlotTag
---@return integer
function Inventory.getInventorySlotCount(name, slotTag)
    return InventoryCollection.getInventorySlotCount(name, slotTag)
end

---@param inventoryType InventoryType
---@param label string
---@return string?
function Inventory.findInventoryByTypeAndLabel(inventoryType, label)
    local inventory = InventoryCollection.findInventoryByTypeAndLabel(inventoryType, label)

    if inventory then
        return inventory.name
    end
end

---@param slot InventorySlot
---@param stack? ItemStack
---@param tag InventorySlotTag
---@param item string
---@return boolean
function Inventory.slotCanProvideItem(slot, stack, tag, item)
    return stack ~= nil and slot.tags[tag] and stack.count > 0 and stack.name == item
end

---@param name string
---@param item string
---@param tag InventorySlotTag
---@return boolean
function Inventory.canProvideItem(name, item, tag)
    local inventory = InventoryCollection.getInventory(name)

    if inventory.items and not inventory.items[item] then
        return false
    end

    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if Inventory.slotCanProvideItem(slot, stack, tag, item) then
            return true
        end
    end

    return false
end

---@param slot InventorySlot
---@param stack? ItemStack
---@param tag InventorySlotTag
---@param allowAllocate boolean
---@param item string
---@return boolean
function Inventory.slotCanTakeItem(slot, stack, tag, allowAllocate, item)
    return slot.tags[tag] and ((stack and stack.name == item and stack.count < stack.maxCount) or (not stack and allowAllocate))
end

---@param name string
---@param item string
---@param tag InventorySlotTag
---@return boolean
function Inventory.canTakeItem(name, item, tag)
    local inventory = InventoryCollection.getInventory(name)

    if not inventory.allowAllocate and inventory.items and not inventory.items[item] then
        return false
    end

    for index, slot in pairs(inventory.slots) do
        if Inventory.slotCanTakeItem(slot, inventory.stacks[index], tag, inventory.allowAllocate, item) then
            return true
        end
    end

    return false
end

---@param name string
---@param item string
---@param tag InventorySlotTag
---@return integer
function Inventory.getItemCount(name, item, tag)
    local inventory = InventoryCollection.getInventory(name)
    local stock = 0

    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if stack and stack.name == item and slot.tags[tag] then
            stock = stock + stack.count
        end
    end

    return stock
end

---@param inventories string[]
---@param item string
---@param tag InventorySlotTag
---@return integer
function Inventory.getTotalItemCount(inventories, item, tag)
    return Utils.sum(inventories, function(name)
        return Inventory.getItemCount(name, item, tag)
    end)
end

---@param name string
---@return integer
function Inventory.getItemsStock(name)
    ---@type integer
    local stock = 0
    local inventory = InventoryCollection.getInventory(name)

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
function Inventory.getStockByTag(tag)
    return InventoryCollection.getStockByTag(tag)
end

---@param name string
---@param tag InventorySlotTag
---@return ItemStock
function Inventory.getInventoryStockByTag(name, tag)
    return InventoryCollection.getInventoryStockByTag(name, tag)
end

---@param inventoryType InventoryType
---@param slotTag InventorySlotTag
---@return ItemStock
function Inventory.getStockByInventoryTypeAndTag(inventoryType, slotTag)
    return InventoryCollection.getStockByInventoryTypeAndTag(inventoryType, slotTag)
end

---@param name string
---@param tag InventorySlotTag
---@return ItemStock
function Inventory.getMaxStockByTag(name, tag)
    ---@type ItemStock
    local stock = {}
    local inventory = InventoryCollection.getInventory(name)

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
function Inventory.getItemStockByTag(name, tag, item)
    local stock = 0
    local inventory = InventoryCollection.getInventory(name)

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
function Inventory.getItemMaxStockByTag(name, tag, item)
    local maxStock = 0
    local inventory = InventoryCollection.getInventory(name)

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
function Inventory.getItemOpenStockByTag(name, tag, item)
    local stock = Inventory.getItemStockByTag(name, tag, item)
    local maxStock = Inventory.getItemMaxStockByTag(name, tag, item)

    return maxStock - stock
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return ItemStock
function Inventory.getStockByTagMultiInventory(inventories, tag)
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
function Inventory.getStack(name, slot)
    return InventoryCollection.getInventory(name).stacks[slot]
end

---@param name string
---@return table<integer, ItemStack>
function Inventory.getStacks(name)
    return InventoryCollection.getInventory(name).stacks
end

---@param name string
---@param slot integer
---@param stack? ItemStack
function Inventory.setStack(name, slot, stack)
    InventoryCollection.getInventory(name).stacks[slot] = stack
end

local function getDefaultRate()
    return 8
end

---@param name string
---@return string
local function removePrefix(name)
    local str = string.gsub(name, "minecraft:", "")
    return str
end

---@param from string
---@param to string
---@param item string
---@param transfer integer
local function toPrintTransferString(from, to, item, transfer)
    return string.format("%s > %s: %dx %s", removePrefix(from), removePrefix(to), transfer, removePrefix(item))
end

---@param from string
---@param to string
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
local function pushItems(from, to, fromSlot, limit, toSlot)
    os.sleep(.25)
    return peripheral.call(from, "pushItems", to, fromSlot, limit, toSlot)
end

---@param inventory Inventory
---@param item string
---@param tag InventorySlotTag
---@return InventorySlot? slot, ItemStack? stack
local function nextFromStack(inventory, item, tag)
    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        -- if stack and slot.tags[tag] and stack.count > 0 and stack.name == item then
        if Inventory.slotCanProvideItem(slot, stack, tag, item) then
            return slot, stack
        end
    end
end

---@param inventory Inventory
---@param item string
---@param tag InventorySlotTag
---@return InventorySlot? slot
local function nextToSlot(inventory, item, tag)
    for index, slot in pairs(inventory.slots) do
        if Inventory.slotCanTakeItem(slot, inventory.stacks[index], tag, inventory.allowAllocate, item) then
            return slot
        end
    end
end

---@param from string
---@param to string
---@param item string
---@param fromTag InventorySlotTag
---@param toTag InventorySlotTag
---@param total? integer
---@param rate? integer
---@return integer transferredTotal
function Inventory.moveItem(from, to, item, fromTag, toTag, total, rate)
    total = total or Inventory.getItemCount(from, item, fromTag)

    if total == 0 then
        return 0
    end

    local fromInventory = InventoryCollection.getInventory(from)
    local toInventory = InventoryCollection.getInventory(to)
    InventoryCollection.lock(from, to)
    local transferredTotal = 0

    pcall(function()
        rate = rate or getDefaultRate()
        local fromSlot, fromStack = nextFromStack(fromInventory, item, fromTag)
        local toSlot = nextToSlot(toInventory, item, toTag)

        while transferredTotal < total and fromSlot and fromStack and fromStack.count > 0 and toSlot do
            local open = total - transferredTotal
            local transfer = math.min(open, rate, fromStack.count)
            local transferred = pushItems(from, to, fromSlot.index, transfer, toSlot.index)

            if transferred == 0 then
                -- either the "from" or the "to" inventory cache is no longer valid.
                -- refreshing both so that distributeItem() doesn't run in an endless loop
                -- [todo] a bit hacky, would like a cleaner way.
                InventoryCollection.remove(from)
                InventoryCollection.remove(to)
                InventoryCollection.mount(from)
                InventoryCollection.mount(to)
                break
            end

            transferredTotal = transferredTotal + transferred
            fromStack.count = fromStack.count - transferred

            if fromStack.count == 0 and not fromSlot.permanent then
                fromInventory.stacks[fromSlot.index] = nil
            end

            local toStack = toInventory.stacks[toSlot.index]

            if toStack then
                toStack.count = toStack.count + transferred
            else
                toInventory.stacks[toSlot.index] = InventoryPeripheral.getStack(to, toSlot.index)
            end

            fromSlot, fromStack = nextFromStack(fromInventory, item, fromTag)
            toSlot = nextToSlot(toInventory, item, toTag)
        end

        if transferredTotal > 0 then
            print(toPrintTransferString(from, to, item, transferredTotal))
        end
    end)

    InventoryCollection.unlock(from, to)

    return transferredTotal
end

---@param from string[]
---@param fromTag InventorySlotTag
---@param to string[]
---@param toTag InventorySlotTag
---@param item string
---@param quantity? integer
---@param options? TransferOptions
---@return integer transferredTotal
function Inventory.transferItem(from, fromTag, to, toTag, item, quantity, options)
    from = getFromCandidates(from, item, fromTag)
    to = getToCandidates(to, item, toTag)
    options = options or {}
    local total = quantity or Inventory.getTotalItemCount(from, item, fromTag)
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
                    local transferred = Inventory.moveItem(fromName, toName, item, fromTag, toTag, transferPerInput, options.rate)
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
---@return ItemStock transferredTotal
function Inventory.transferItems(from, fromTag, to, toTag, items, options)
    ---@type ItemStock
    local transferredTotal = {}

    for item, quantity in pairs(items) do
        local transferred = Inventory.transferItem(from, fromTag, to, toTag, item, quantity, options)

        if transferred > 0 then
            transferredTotal[item] = transferred
        end
    end

    return transferredTotal
end

--- Transfer items found in slots of "from" inventory matching "fromTag" from one inventory to the other.
---@param from string
---@param to string
---@param fromTag InventorySlotTag
---@param toTag InventorySlotTag
---@param total? ItemStock
---@return ItemStock transferredTotal, ItemStock open
function Inventory.transferFromTag(from, to, fromTag, toTag, total)
    local itemStock = Inventory.getInventoryStockByTag(from, fromTag)
    ---@type ItemStock
    local transferredTotal = {}
    ---@type ItemStock
    local open = {}
    total = total or {}

    for item, stock in pairs(itemStock) do
        local transfer = total[item] or stock
        local transferred = Inventory.moveItem(from, to, item, fromTag, toTag, transfer)

        if transferred > 0 then
            transferredTotal[item] = transferred

            if transferred < transfer then
                open[item] = transfer - transferred
            end
        else
            open[item] = transfer
        end
    end

    return transferredTotal, open
end

---@param from string[]
---@param to string[]
---@param item string
---@param fromTag InventorySlotTag
---@param toTag InventorySlotTag
---@param total? integer
---@return integer transferredTotal
function Inventory.distributeItem(from, to, item, fromTag, toTag, total)
    from = getFromCandidates(from, item, fromTag)
    to = getToCandidates(to, item, toTag)
    total = total or Inventory.getTotalItemCount(from, item, fromTag)
    local totalTransferred = 0

    while totalTransferred < total and #from > 0 and #to > 0 do
        if #from == 1 and #to == 1 and from[1] == to[1] then
            break
        end

        local transferPerOutput = (total - totalTransferred) / #from
        local transferPerInput = math.max(1, math.floor(transferPerOutput / #to))

        --- [todo] in regards to locking/unlocking:
        --- previously, before the rewrite, we were sorting based on lock-state, i.e. take inventories first that are not locked.
        --- we really should have that functionality again to make sure the system is not super slow in some cases.
        --- I'm thinking of doing that logic exactly here, as I assume all future distribute() methods will make use of distributeItem().
        for _, fromName in ipairs(from) do
            for _, toName in ipairs(to) do
                if fromName ~= toName then
                    local transferred = Inventory.moveItem(fromName, toName, item, fromTag, toTag, transferPerInput)
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
---@param to string[]
---@param items ItemStock
---@param fromTag InventorySlotTag
---@param toTag InventorySlotTag
---@return ItemStock transferredTotal
function Inventory.distributeItems(from, to, items, fromTag, toTag)
    return Inventory.transferItems(from, fromTag, to, toTag, items)
end

---@param from string[]
---@param to string[]
---@param fromTag InventorySlotTag
---@param toTag InventorySlotTag
---@return ItemStock transferredTotal
function Inventory.distributeFromTag(from, to, fromTag, toTag)
    if #from == 0 or #to == 0 then
        return {}
    end

    local fromStock = Inventory.getStockByTagMultiInventory(from, fromTag)
    ---@type ItemStock
    local filteredFromStock = {}

    if Utils.find(to, function(name)
        return InventoryCollection.getInventory(name).allowAllocate
    end) then
        filteredFromStock = fromStock
    else
        local toStock = Inventory.getStockByTagMultiInventory(to, toTag)

        for item, quantity in pairs(fromStock) do
            if toStock[item] then
                filteredFromStock[item] = quantity
            end
        end
    end

    return Inventory.distributeItems(from, to, filteredFromStock, fromTag, toTag)
end

local function onPeripheralEventMountInventory()
    while true do
        EventLoop.pull("peripheral", function(_, name)
            if InventoryReader.isInventoryType(name) then
                InventoryCollection.mount(name)
            end
        end)
    end
end

function Inventory.discover()
    print("[inventory] mounting connected inventories...")
    local names = peripheral.getNames()
    local mountFns = Utils.map(names, function(name)
        return function()
            if InventoryReader.isInventoryType(name) then
                InventoryCollection.mount(name)
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
function Inventory.start()
    EventLoop.runUntil("inventory:stop", function()
        onPeripheralEventMountInventory()
    end, function()
        while true do
            EventLoop.pull("peripheral_detach", function(_, name)
                if InventoryCollection.isMounted(name) then
                    print("[unmount]", name)
                    InventoryCollection.remove(name)
                end
            end)
        end
    end)
end

function Inventory.stop()
    InventoryCollection.clear()
    EventLoop.queue("inventory:stop")
end

return Inventory
