local InventoryAdvanced = require "inventory.inventory-advanced"

---@class InventoryComplex:InventoryAdvanced
local InventoryComplex = {}
setmetatable(InventoryComplex, {__index = InventoryAdvanced})

return InventoryComplex
