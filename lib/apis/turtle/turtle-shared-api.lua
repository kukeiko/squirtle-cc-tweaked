---@class TurtleSharedApi
local TurtleSharedApi = {}

---@type fun(items: table<string, integer>, alwaysUseShulker: boolean?) : nil
local requireItemsFn = function()
    error("requireItems() not bound")
end

---@param requireItems fun(items: table<string, integer>, alwaysUseShulker: boolean?) : nil
function TurtleSharedApi.setRequireItems(requireItems)
    requireItemsFn = requireItems
end

---@param items table<string, integer>
---@param alwaysUseShulker boolean?
function TurtleSharedApi.requireItems(items, alwaysUseShulker)
    return requireItemsFn(items, alwaysUseShulker)
end

---@param item string
---@param quantity? integer
---@param alwaysUseShulker? boolean
function TurtleSharedApi.requireItem(item, quantity, alwaysUseShulker)
    quantity = quantity or 1
    TurtleSharedApi.requireItems({[item] = quantity}, alwaysUseShulker)
end

---@type fun() : string
local placeShulkerFn = function()
    error("placeShulker() not bound")
end

---@param placeShulker fun() : string
function TurtleSharedApi.setPlaceShulker(placeShulker)
    placeShulkerFn = placeShulker
end

---@return string
function TurtleSharedApi.placeShulker()
    return placeShulkerFn()
end

---@type fun(side: string) : nil
local digShulkerFn = function()
    error("digShulker() not bound")
end

---@param digShulker fun(side: string) : nil
function TurtleSharedApi.setDigShulker(digShulker)
    digShulkerFn = digShulker
end

---@param side string
function TurtleSharedApi.digShulker(side)
    return digShulkerFn(side)
end

return TurtleSharedApi
