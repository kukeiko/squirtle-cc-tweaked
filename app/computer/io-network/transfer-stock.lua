local Utils = require "utils"
local Inventory = require "inventory.inventory"

---@param collection InventoryCollection
---@param output Inventory
---@param input Inventory
---@param item string
---@param quantity integer
---@param allowAllocate? boolean
---@return integer transferred
local function transferToInputInventory(collection, output, input, item, quantity, allowAllocate)
    local missingStock = Inventory.getSpaceForItem(input, item)
    local availableStock = output.stock[item].count
    local transfer = math.min(quantity, missingStock, availableStock)
    -- os.sleep(1)
    collection:lock(output, input)
    local transferred = Inventory.transferItem(output, input, item, transfer, nil, allowAllocate)
    collection:unlock(output, input)

    return transferred
end

---@param stock ItemStack
---@param from InputOutputInventory[]
---@param to InputOutputInventory[]
---@param collection InventoryCollection
---@param allowAllocate? boolean
---@return integer
local function transferStock(stock, from, to, collection, allowAllocate)
    if stock.count < 0 then
        return 0
    end

    local transferTarget = stock.count

    local outputInventories = Utils.map(from, function(inventory)
        return inventory.output
    end)

    local inputInventories = Utils.map(to, function(inventory)
        return inventory.input
    end)

    local transferredTotal = 0

    outputInventories = Inventory.filterCanProvideItem(outputInventories, stock.name)
    inputInventories = Inventory.filterHasSpaceForItem(inputInventories, stock.name)

    ---@type Inventory[]
    local nextCycleOutputInventories = {}
    ---@type Inventory[]
    local nextCycleInputInventories = {}

    while #outputInventories > 0 and #inputInventories > 0 do
        local transferPerOutput = (transferTarget - transferredTotal) / #outputInventories

        while #outputInventories > 0 do
            local output, outputIndex = collection:waitUntilAnyUnlocked(table.unpack(outputInventories))
            local sameInventory, sameInventoryIndex = Utils.find(inputInventories, function(item)
                return item.name == output.name
            end)

            if sameInventory and sameInventoryIndex then
                table.remove(inputInventories, sameInventoryIndex)

                if #inputInventories > 0 then
                    table.insert(nextCycleInputInventories, sameInventory)
                    os.sleep(1) -- [todo] why sleep?
                end
            end

            local transferPerInput = math.max(1, math.floor(transferPerOutput / #inputInventories))

            while #inputInventories > 0 and transferredTotal < transferTarget do
                local input, inputIndex = collection:waitUntilAnyUnlocked(table.unpack(inputInventories))
                -- [todo] we're not dealing with the case where 0 was transferred,
                -- which can be caused by interference from the player.
                -- we need to either remove the output or the input inventory from the list of inventories
                -- for the next cycle, otherwise we run into an endless loop.
                local transferred = transferToInputInventory(collection, output, input, stock.name, transferPerInput, allowAllocate)
                transferredTotal = transferredTotal + transferred

                table.remove(inputInventories, inputIndex)

                if Inventory.hasSpaceForItem(input, stock.name) then
                    table.insert(nextCycleInputInventories, input)
                end
            end

            if #inputInventories == 0 then
                inputInventories = nextCycleInputInventories
                nextCycleInputInventories = {}
            end

            table.remove(outputInventories, outputIndex)

            if Inventory.canProvideItem(output, stock.name) then
                table.insert(nextCycleOutputInventories, output)
            end
        end

        if #outputInventories == 0 then
            outputInventories = nextCycleOutputInventories
            nextCycleOutputInventories = {}
        end
    end

    return transferredTotal
end

---@param stock ItemStock
---@param from InputOutputInventory[]
---@param to InputOutputInventory[]
---@param collection InventoryCollection
---@param allowAllocate? boolean
return function(stock, from, to, collection, allowAllocate)
    for _, itemStock in pairs(stock) do
        transferStock(itemStock, from, to, collection, allowAllocate)
    end
end
