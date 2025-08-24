local TurtleInventoryApi = require "lib.turtle.api-parts.turtle-inventory-api"

---@class TurtleInventoryService : Service
local TurtleInventoryService = {name = "turtle-inventory-service"}

---@return integer
function TurtleInventoryService.getSize()
    return TurtleInventoryApi.size()
end

---@param slot integer
---@return ItemStack?
function TurtleInventoryService.getStack(slot)
    return TurtleInventoryApi.getStack(slot, true)
end

---@param detailed? boolean
---@return ItemStacks
function TurtleInventoryService.getStacks(detailed)
    return TurtleInventoryApi.getStacks(detailed)
end

return TurtleInventoryService
