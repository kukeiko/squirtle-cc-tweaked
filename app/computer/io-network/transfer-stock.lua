local Utils = require "utils"
local transferItem = require "inventory.transfer-item"

---@param inventories Inventory[]
---@param item string
---@param provide boolean?
---@return Inventory[]
local function filterInventories(inventories, item, provide)
    local others = {}
    provide = provide or false

    for _, candidate in ipairs(inventories) do
        local stock = candidate.stock[item];

        if stock and ((provide and stock.count > 0) or (not provide and stock.count < stock.maxCount)) then
            table.insert(others, candidate)
        end
    end

    return others
end

---@param inventory Inventory
---@param item string
---@return boolean
local function canProvideItem(inventory, item)
    local stock = inventory.stock[item]

    return stock and stock.count > 0
end

---@param inventory Inventory
---@param item string
---@return boolean
local function hasSpaceForItem(inventory, item)
    local stock = inventory.stock[item]

    return stock and stock.count < stock.maxCount
end

---@param name string
---@return string
local function removePrefix(name)
    local str = string.gsub(name, "minecraft:", "")
    return str
end

---@param from Inventory
---@param to Inventory
---@param item string
---@param transfer integer
local function toPrintTransferString(from, to, item, transfer)
    return
        string.format("%s > %s: %dx %s", removePrefix(from.name), removePrefix(to.name), transfer, removePrefix(item))
end

---@param stock ItemStack
---@param from InputOutputInventory[]
---@param to InputOutputInventory[]
---@param collection InventoryCollection
---@return integer
local function transferStock(stock, from, to, collection)
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

    outputInventories = filterInventories(outputInventories, stock.name, true)
    inputInventories = filterInventories(inputInventories, stock.name, false)

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
                    os.sleep(1)
                end
            end

            local transferPerInput = math.max(1, math.floor(transferPerOutput / #inputInventories))

            while #inputInventories > 0 do
                local input, inputIndex = collection:waitUntilAnyUnlocked(table.unpack(inputInventories))
                local missingStock = input.stock[stock.name].maxCount - input.stock[stock.name].count
                local availableStock = output.stock[stock.name].count
                local transfer = math.min(transferPerInput, missingStock, availableStock)
                print(toPrintTransferString(output, input, stock.name, transfer))

                collection:lock(output, input)
                local transferred = transferItem(output, input, stock.name, transfer)
                collection:unlock(output, input)
                transferredTotal = transferredTotal + transferred

                if (transferredTotal >= transferTarget) or transferred ~= transfer then
                    print("[transfer] amount mismatch")
                    return transferredTotal
                end

                table.remove(inputInventories, inputIndex)

                if hasSpaceForItem(input, stock.name) then
                    table.insert(nextCycleInputInventories, input)
                end
            end

            if #inputInventories == 0 then
                inputInventories = nextCycleInputInventories
                nextCycleInputInventories = {}
            end

            table.remove(outputInventories, outputIndex)

            if canProvideItem(output, stock.name) then
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
return function(stock, from, to, collection)
    for _, itemStock in pairs(stock) do
        transferStock(itemStock, from, to, collection)
    end
end
