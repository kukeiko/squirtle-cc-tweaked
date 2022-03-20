---@class KiwiItemStack
---@field count integer
---@field name string
local ItemStack = {}

---@param data table
---@return KiwiItemStack
function ItemStack.cast(data)
    return data;
end

return ItemStack
