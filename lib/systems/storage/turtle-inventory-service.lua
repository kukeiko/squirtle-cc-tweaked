local TurtleApi = require "lib.apis.turtle.turtle-api"

---@class TurtleInventoryService : Service
local TurtleInventoryService = {name = "turtle-inventory-service"}

---@return integer
function TurtleInventoryService.getSize()
    return TurtleApi.size()
end

---@param slot integer
---@return ItemStack?
function TurtleInventoryService.getStack(slot)
    return TurtleApi.getStack(slot, true)
end

---@param detailed? boolean
---@return ItemStacks
function TurtleInventoryService.getStacks(detailed)
    return TurtleApi.getStacks(detailed)
end

return TurtleInventoryService
