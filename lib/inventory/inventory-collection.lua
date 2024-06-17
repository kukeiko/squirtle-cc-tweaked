local Utils = require "utils"
local EventLoop = require "event-loop"
local InventoryReader = require "inventory.inventory-reader"

---@class InventoryCollection
---@field useCache boolean
local InventoryCollection = {useCache = false}

---@type table<string, Inventory>
local inventories = {}
---@type table<string, string>
local locks = {}

---@param name string
---@return Inventory
function InventoryCollection.getInventory(name)
    if not inventories[name] then
        InventoryCollection.mount(name)
    end

    if InventoryCollection.useCache then
        return inventories[name]
    end

    return InventoryCollection.refresh(name)
end

---@param inventoryType InventoryType
---@param label string
---@return Inventory?
function InventoryCollection.findInventoryByTypeAndLabel(inventoryType, label)
    for _, inventory in pairs(inventories) do
        if inventory.type == inventoryType and inventory.label == label then
            return inventory
        end
    end
end

--- Reads & adds the inventory to the collection if it doesn't already exist.
---@param name string
---@param expected? InventoryType
function InventoryCollection.mount(name, expected)
    if not inventories[name] then
        inventories[name] = InventoryReader.read(name, expected)
    end

    if expected and inventories[name].type ~= expected then
        error(string.format("inventory %s is not of expected type %s", name, expected))
    end
end

---@param name string
---@return boolean
function InventoryCollection.isMounted(name)
    return inventories[name] ~= nil
end

---@param name string
function InventoryCollection.remove(name)
    inventories[name] = nil
    locks[name] = nil
    InventoryCollection.removeLocksFrom(name)
end

---@param name string
---@return Inventory
function InventoryCollection.refresh(name)
    InventoryCollection.lockOne(name)
    inventories[name] = InventoryReader.read(name)
    InventoryCollection.unlockOne(name)

    return inventories[name]
end

---@param type InventoryType
function InventoryCollection.refreshByType(type)
    ---@type string[]
    local names = {}

    for name, inventory in pairs(inventories) do
        if inventory.type == type then
            table.insert(names, name)
        end
    end

    local fns = Utils.map(names, function(name)
        return function()
            InventoryCollection.refresh(name)
        end
    end)

    local chunkedFns = Utils.chunk(fns, 32)

    for _, chunk in pairs(chunkedFns) do
        EventLoop.run(table.unpack(chunk))
        os.sleep(1)
    end
end

function InventoryCollection.clear()
    inventories = {}
    locks = {}
end

---@param output string
---@param input string
function InventoryCollection.lock(output, input)
    InventoryCollection.waitUntilAllUnlocked(output, input)
    locks[output] = output
    locks[input] = output
end

---@param name string
function InventoryCollection.lockOne(name)
    InventoryCollection.waitUntilAllUnlocked(name)
    locks[name] = name
end

---@param output string
---@param input string
function InventoryCollection.unlock(output, input)
    locks[output] = nil
    locks[input] = nil
end

---@param name string
function InventoryCollection.unlockOne(name)
    locks[name] = nil
end

---@param name string
function InventoryCollection.removeLocksFrom(name)
    for locked, lockedBy in pairs(Utils.copy(locks)) do
        if lockedBy == name then
            print("[unlock]", locked)
            locks[locked] = nil
        end
    end
end

---@param name string
---@return boolean
function InventoryCollection.isLocked(name)
    return locks[name] ~= nil
end

---@param ... Inventory
---@return Inventory, integer
function InventoryCollection.waitUntilAnyUnlocked(...)
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
function InventoryCollection.waitUntilAllUnlocked(...)
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

---@param type InventoryType?
---@param refresh boolean?
---@return string[]
function InventoryCollection.getInventories(type, refresh)
    ---@type string[]
    local array = {}

    for name, inventory in pairs(inventories) do
        if type == nil or inventory.type == type then
            if refresh then
                inventory = InventoryCollection.refresh(name)
            end

            table.insert(array, name)
        end
    end

    return array
end

---@param name string
---@param tag InventorySlotTag
---@return ItemStock
function InventoryCollection.getInventoryStockByTag(name, tag)
    ---@type ItemStock
    local stock = {}
    local inventory = InventoryCollection.getInventory(name)

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

    for _, inventory in pairs(inventories) do
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
    local inventories = InventoryCollection.getInventories(inventoryType)
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
