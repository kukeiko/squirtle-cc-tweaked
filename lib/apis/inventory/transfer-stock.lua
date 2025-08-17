local Utils = require "lib.tools.utils"
local transferItem = require "lib.apis.inventory.transfer-item"

---@param from InventoryHandle
---@param to InventoryHandle
---@param items ItemStock
---@param options? TransferOptions
---@return boolean transferredAll, ItemStock transferred, ItemStock open
return function(from, to, items, options)
    ---@type ItemStock
    local transferredTotal = {}
    ---@type ItemStock
    local open = {}

    for item, quantity in pairs(items) do
        local transferred = transferItem(from, to, item, quantity, options)

        if transferred > 0 then
            transferredTotal[item] = transferred

            if transferred < quantity then
                open[item] = quantity - transferred
            end
        elseif quantity > 0 then
            open[item] = quantity
        end
    end

    return Utils.isEmpty(open), transferredTotal, open
end
