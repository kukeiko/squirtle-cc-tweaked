local getStacks = require "world.chest.get-stacks"
local toIoInventory = require "inventory.to-io-inventory"
local transferItem = require "inventory.transfer-item"
local stacksToStock = require "inventory.stacks-to-stock"

-- [todo] keepStock is not used yet anywhere; but i want to keep it because it should (imo)
-- be used @ lumberjack to push birch-saplings, but make sure to always keep at least 32
---@param from string
---@param to string
---@param keepStock? table<string, integer>
---@return boolean, table<string, integer>
return function(from, to, keepStock)
    keepStock = keepStock or {}

    ---@type  table<string, integer>
    local transferredStock = {}
    local fromStacks = getStacks(from)
    ---@type Inventory
    local fromInventory = {name = from, stacks = fromStacks, stock = stacksToStock(fromStacks)}

    local toInventory = toIoInventory(to)
    local transferredAll = true

    for item, stock in pairs(toInventory.output.stock) do
        local fromStock = fromInventory.stock[item]

        if fromStock then
            local pushable = math.max(fromStock.count - (keepStock[item] or 0), 0)
            local open = stock.maxCount - stock.count
            local transfer = math.min(open, pushable)

            while stock.count < stock.maxCount do
                local transferred = transferItem(fromInventory, toInventory.output, item, transfer, 16)
                transferredStock[item] = (transferredStock[item] or 0) + transferred

                if transferred ~= transfer then
                    -- assuming chest is full or its state changed from an external source, in which case we just ignore it
                    break
                end
            end

            if fromStock.count - (keepStock[item] or 0) > 0 then
                transferredAll = false
            end
        end
    end

    return transferredAll, transferredStock
end

