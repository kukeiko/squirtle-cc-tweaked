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

    EventLoop.run(table.unpack(fns))
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

        print("[locked]")
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
        if inventory.type == type then
            if refresh then
                inventory = InventoryCollection.refresh(name)
            end

            if inventory.type == type then
                table.insert(array, name)
            end
        end
    end

    return array
end

return InventoryCollection
