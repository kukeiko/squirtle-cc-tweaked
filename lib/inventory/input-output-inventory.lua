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


return InputOutputInventory
