local Utils = require "utils"

---@class InventoryCollection
---@field inventories table<string, InputOutputInventory>
---@field locks table<string, string>
local InventoryCollection = {}

---@type InputOutputInventoryType[]
local allTypes = {"storage", "io", "drain", "furnace", "silo", "shulker"}

---@return InventoryCollection
function InventoryCollection.new()
    ---@type InventoryCollection
    local instance = {inventories = {}, locks = {}}
    setmetatable(instance, {__index = InventoryCollection})

    return instance
end

---@param ioInventory InputOutputInventory
function InventoryCollection:add(ioInventory)
    self.inventories[ioInventory.name] = ioInventory
end

---@param name string
function InventoryCollection:remove(name)
    self.inventories[name] = nil
    self.locks[name] = nil
    self:removeLocksFrom(name)
end

---@param output Inventory
---@param input Inventory
function InventoryCollection:lock(output, input)
    self:waitUntilAllUnlocked(output, input)
    self.locks[output.name] = output.name
    self.locks[input.name] = output.name
end

---@param output Inventory
---@param input Inventory
function InventoryCollection:unlock(output, input)
    self.locks[output.name] = nil
    self.locks[input.name] = nil
end

---@param name string
function InventoryCollection:removeLocksFrom(name)
    for locked, lockedBy in pairs(Utils.copy(self.locks)) do
        if lockedBy == name then
            print("[unlock]", locked)
            self.locks[locked] = nil
        end
    end
end

---@param name string
---@return boolean
function InventoryCollection:isLocked(name)
    return self.locks[name] ~= nil
end

---@param ... Inventory
---@return Inventory, integer
function InventoryCollection:waitUntilAnyUnlocked(...)
    local inventories = {...}

    while true do
        for index, inventory in pairs(inventories) do
            if not self:isLocked(inventory.name) then
                return inventory, index
            end
        end

        os.sleep(3)
    end
end

---@param ... Inventory
function InventoryCollection:waitUntilAllUnlocked(...)
    local inventories = {...}

    while true do
        local anyLocked = false

        for _, inventory in pairs(inventories) do
            if self:isLocked(inventory.name) then
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

---@param type InputOutputInventoryType?
---@return InputOutputInventory[]
function InventoryCollection:getInventories(type)
    ---@type InputOutputInventory[]
    local array = {}

    for _, inventory in pairs(self.inventories) do
        if not type or (type and inventory.type == type) then
            table.insert(array, inventory)
        end
    end

    return array
end

---@param item string
---@param inventoryTypes InputOutputInventoryType[]?
---@return Inventory[]
function InventoryCollection:getInputsAcceptingItem(item, inventoryTypes)
    inventoryTypes = inventoryTypes or allTypes

    ---@type Inventory[]
    local inventories = {}

    for _, inventory in pairs(self.inventories) do
        local stock = inventory.input.stock[item]

        if Utils.indexOf(inventoryTypes, inventory.type) > 0 and stock and stock.count < stock.maxCount then
            table.insert(inventories, inventory)
        end
    end

    return inventories
end

return InventoryCollection
