local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local TurtleInventoryService = require "lib.turtle.turtle-inventory-service"

---@class TurtleInventoryAdapter : InventoryAdapter
local TurtleInventoryAdapter = {}

---@param inventory string
local function connect(inventory)
    return Rpc.connect(TurtleInventoryService, inventory, 0.25, "wired")
end

---@param name string
---@return boolean
local function isTurtlePeripheral(name)
    return Utils.startsWith(name, "turtle_")
end

---@param inventory string
---@return boolean
function TurtleInventoryAdapter.isPresent(inventory)
    -- [todo] ❌ should add tryConnect() to RPC to prevent using a pcall
    local success = pcall(function()
        connect(inventory)
    end)

    return success
end

---@param inventory string
---@return boolean
function TurtleInventoryAdapter.accept(inventory)
    return isTurtlePeripheral(inventory)
end

---@param inventory string
---@return integer
function TurtleInventoryAdapter.getSize(inventory)
    return connect(inventory).getSize()
end

---@param inventory string
---@param slot integer
---@return ItemStack?
function TurtleInventoryAdapter.getStack(inventory, slot)
    return connect(inventory).getStack(slot)
end

---@param inventory string
---@param detailed? boolean
---@return ItemStacks
function TurtleInventoryAdapter.getStacks(inventory, detailed)
    return connect(inventory).getStacks(detailed)
end

---@param from string
---@param to string
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function TurtleInventoryAdapter.transfer(from, to, fromSlot, limit, toSlot)
    if isTurtlePeripheral(to) then
        error("can't transfer items between turtles")
    end

    return peripheral.call(to, "pullItems", from, fromSlot, limit, toSlot)
end

return TurtleInventoryAdapter
