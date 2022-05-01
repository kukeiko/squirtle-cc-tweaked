---@param chest string
---@return integer
return function(chest)
    return peripheral.call(chest, "getSize")
end
