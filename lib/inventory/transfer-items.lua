local getDefaultRate = require "inventory.get-default-rate"
local transferItem = require "inventory.transfer-item"

---@param from Inventory
---@param to Inventory
---@param total table<string, integer>
---@param rate? integer
---@param allowAllocate? boolean
---@return table<string,integer> transferred
return function(from, to, total, rate, allowAllocate)
    rate = rate or getDefaultRate()

    ---@type table<string, integer>
    local transferredTotal = {}

    for item, itemTotal in pairs(total) do
        local transferred = transferItem(from, to, item, itemTotal, rate, allowAllocate)

        if transferred > 0 then
            transferredTotal[item] = transferred
        end
    end

    return transferredTotal
end
