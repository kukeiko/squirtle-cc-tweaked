local InputOutputInventory = {}

---@param name string
---@param input Inventory
---@param output Inventory
---@param type InputOutputInventoryType?
---@param tagSlot? integer
---@return InputOutputInventory
function InputOutputInventory.create(name, input, output, type, tagSlot)
    ---@type InputOutputInventory
    -- [todo] tagSlot
    local inventory = {name = name, input = input, output = output, type = type or "io", tagSlot = tagSlot or -1}

    return inventory
end

---@alias InputOutputInventoryType "storage" | "io" | "drain" | "furnace" | "silo" | "shulker" | "crafter" | "furnace-input" | "furnace-output"
---@class InputOutputInventory
---@field name string
---@field tagSlot integer
---@field input Inventory
---@field output Inventory
---@field type InputOutputInventoryType

return InputOutputInventory
