---@class DetailedItemStack
---@field count integer
---@field name string
---@field maxCount integer
---@field displayName string
---@field tags table
---@field nbt string|nil
local DetailedItemStack = {}

---@param data table
---@return DetailedItemStack
function DetailedItemStack.cast(data)
    setmetatable(data, {__index = DetailedItemStack})
    return data;
end

function DetailedItemStack:numMissing()
    return self.maxCount - self.count
end

---@param other DetailedItemStack
function DetailedItemStack:equals(other)
    return self.name == other.name and self.displayName == other.displayName and self.nbt == other.nbt
end

return DetailedItemStack
