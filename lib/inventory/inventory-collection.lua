local Utils = require "lib.common.utils"
local EventLoop = require "lib.common.event-loop"
local InventoryReader = require "lib.inventory.inventory-reader"

---@class InventoryCollection
---@field useCache boolean
local InventoryCollection = {useCache = false}

---@type table<string, Inventory>
local cache = {}
---@type table<string, string>
local locks = {}

---@param ... Inventory
---@return Inventory, integer
local function awaitUnlockAny(...)
    local inventories = {...}

    while true do
        for index, inventory in pairs(inventories) do
            if not InventoryCollection.isLocked(inventory.name) then
                return inventory, index
            end
        end

        os.sleep(3)
    end
end

---@param ... string
local function awaitUnlockAll(...)
    local inventories = {...}

    while true do
        local anyLocked = false

        for _, inventory in pairs(inventories) do
            if InventoryCollection.isLocked(inventory) then
                anyLocked = true
                break
            end
        end

        if not anyLocked then
            return nil
        end

        print("[locked]", table.concat({...}, ", "))
        os.sleep(3)
    end
end

function InventoryCollection.clear()
    cache = {}
    locks = {}
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

---@return string[]
function InventoryCollection.getAll()
    return Utils.map(cache, function(_, index)
        return index
    end)
end

---@param type InventoryType
---@return string[]
function InventoryCollection.getByType(type)
    return Utils.filterMapProjectList(cache, function(item)
        return item.type == type
    end, function(item)
        return item.name
    end)
end

---@param inventoryType InventoryType
---@param label string
---@return Inventory?
function InventoryCollection.findByTypeAndLabel(inventoryType, label)
    for _, inventory in pairs(cache) do
        if inventory.type == inventoryType and inventory.label == label then
            return inventory
        end
    end
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
        locks[inventory] = nil

        for locked, lockedBy in pairs(Utils.copy(locks)) do
            if lockedBy == inventory then
                print("[unlock]", locked)
                locks[locked] = nil
            end
        end
    end
end

---@param name string
---@return boolean
function InventoryCollection.isMounted(name)
    return cache[name] ~= nil
end

---@param inventories string[]
function InventoryCollection.refresh(inventories)
    local fns = Utils.map(inventories, function(inventory)
        return function()
            local unlock = InventoryCollection.lock(inventory, {inventory})
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

---@param lockedBy string
---@param inventories string[]
---@return fun() : nil
function InventoryCollection.lock(lockedBy, inventories)
    awaitUnlockAll(table.unpack(inventories))

    for _, inventory in pairs(inventories) do
        locks[inventory] = lockedBy
    end

    return function()
        for _, inventory in pairs(inventories) do
            locks[inventory] = nil
        end
    end
end

---@param name string
---@return boolean
function InventoryCollection.isLocked(name)
    return locks[name] ~= nil
end

---@param inventories string[]
---@param item string
---@param tag InventorySlotTag
---@return integer
function InventoryCollection.getItemCount(inventories, item, tag)
    local stock = 0

    for _, inventory in pairs(inventories) do
        local inventory = InventoryCollection.get(inventory)

        for index, slot in pairs(inventory.slots) do
            local stack = inventory.stacks[index]

            if stack and stack.name == item and slot.tags[tag] then
                stock = stock + stack.count
            end
        end
    end

    return stock
end

---@param name string
---@param tag InventorySlotTag
---@return integer
function InventoryCollection.getSlotCount(name, tag)
    local inventory = InventoryCollection.get(name)
    local count = 0

    for _, slot in pairs(inventory.slots) do
        if slot.tags[tag] == true then
            count = count + 1
        end
    end

    return count
end

---@param name string
---@param tag InventorySlotTag
---@param refresh? boolean
---@return ItemStock
function InventoryCollection.getInventoryStockByTag(name, tag, refresh)
    if refresh then
        InventoryCollection.refresh({name})
    end

    ---@type ItemStock
    local stock = {}
    local inventory = InventoryCollection.get(name)

    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if stack and slot.tags[tag] then
            stock[stack.name] = (stock[stack.name] or 0) + stack.count
        end
    end

    return stock
end

---@param tag InventorySlotTag
---@return ItemStock
function InventoryCollection.getStockByTag(tag)
    ---@type ItemStock
    local stock = {}

    for _, inventory in pairs(cache) do
        for item, quantity in pairs(InventoryCollection.getInventoryStockByTag(inventory.name, tag)) do
            stock[item] = (stock[item] or 0) + quantity
        end
    end

    return stock
end

---@param inventoryType InventoryType
---@param slotTag InventorySlotTag
---@return ItemStock
function InventoryCollection.getStockByInventoryTypeAndTag(inventoryType, slotTag)
    local inventories = InventoryCollection.getByType(inventoryType)
    ---@type ItemStock
    local stock = {}

    for _, name in pairs(inventories) do
        for item, quantity in pairs(InventoryCollection.getInventoryStockByTag(name, slotTag)) do
            stock[item] = (stock[item] or 0) + quantity
        end
    end

    return stock
end

return InventoryCollection
