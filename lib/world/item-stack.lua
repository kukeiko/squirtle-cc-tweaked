---@class ItemStack
---@field count integer
---@field name string
local ItemStack = {}

---@param data table
---@return ItemStack
function ItemStack.cast(data)
    return data;
end

return ItemStack
