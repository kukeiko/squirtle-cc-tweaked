local InventoryCollection = require "lib.inventory.inventory-collection"

---@param handle InventoryHandle
---@return InventoryType?
local function getTypeByHandle(handle)
    if type(handle) == "number" then
        return "buffer"
    elseif type(handle) == "string" then
        return "stash"
    end

    return nil
end

---@param type InventoryType?
---@param options TransferOptions
---@return TransferOptions
local function getDefaultFromOptions(type, options)
    if type == "buffer" and options.fromSequential == nil then
        options.fromSequential = true
    end

    if options.fromTag == nil then
        if type == "buffer" or type == "stash" then
            options.fromTag = "buffer"
        else
            options.fromTag = "output"
        end
    end

    return options
end

---@param type InventoryType?
---@param options TransferOptions
---@return TransferOptions
local function getDefaultToOptions(type, options)
    if type == "buffer" and options.toSequential == nil then
        options.toSequential = true
    end

    if options.toTag == nil then
        if type == "buffer" or type == "stash" then
            options.toTag = "buffer"
        else
            options.toTag = "input"
        end
    end

    return options
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param options? TransferOptions
---@return string[] from, string[] to, TransferOptions options
return function(from, to, options)
    local fromType = getTypeByHandle(from)
    local toType = getTypeByHandle(to)
    local options = getDefaultFromOptions(fromType, options or {})
    options = getDefaultToOptions(toType, options)

    return InventoryCollection.resolveHandle(from), InventoryCollection.resolveHandle(to), options
end
