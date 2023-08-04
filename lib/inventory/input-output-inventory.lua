local InputOutputInventory = {}

---@param name string
---@param input Inventory
---@param output Inventory
---@param type InputOutputInventoryType?
---@return InputOutputInventory
function InputOutputInventory.create(name, input, output, type)
    ---@type InputOutputInventory
    local inventory = {name = name, input = input, output = output, type = type or "io"}

    return inventory
end

---@alias InputOutputInventoryType "storage" | "io" | "drain" | "furnace" | "silo"
---@class InputOutputInventory
---@field name string
---@field input Inventory
---@field output Inventory
---@field type InputOutputInventoryType

return InputOutputInventory
