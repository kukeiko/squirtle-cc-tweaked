package.path = package.path .. ";/?.lua"

local KiwiChest = require "kiwi.core.chest"
local KiwiPeripheral = require "kiwi.core.peripheral"
local KiwiUtils = require "kiwi.utils"

---@param chest KiwiChest
---@return table<string, integer>
local function readInputStock(chest)
    local items = chest:getDetailedItemList()

    ---@type table<string, integer>
    local requiredInputStock = {}

    -- [todo] hardcoded input slot range
    for slot = 1, 9 do
        local item = items[slot]

        if item ~= nil then
            requiredInputStock[item.name] = (requiredInputStock[item.name] or 0) + item.maxCount
        end
    end

    return requiredInputStock
end

---@param source KiwiChest
---@param target KiwiChest
local function doTheThing(source, target)
    -- figure out how much per item we need to satisfy input by reading input line from target.
    -- then have a look at how much we of it in source and subtract the stock.
    -- resulting negative values mean that we have enough of it; and that we could use
    -- that many to push to output.
    -- positive values mean that we need to load that input from target to source.
    -- after that, read output lines in target chest, and for each stack,
    -- if input count table value is either negative or non existant,
    -- find that in source and push to target, where transferCount is based on input table value

    local requiredInputStock = readInputStock(target)
    KiwiUtils.prettyPrint(requiredInputStock)

    for _, sourceItem in pairs(source:getDetailedItemList()) do
        if requiredInputStock[sourceItem.name] ~= nil then
            requiredInputStock[sourceItem.name] = requiredInputStock[sourceItem.name] - sourceItem.count
        else
            -- [todo] by introducing this else block, the name "requiredInputStock" is now confusing
            requiredInputStock[sourceItem.name] = -sourceItem.count
        end
    end

    KiwiUtils.prettyPrint(requiredInputStock)

    -- push output
    local sourceItems = source:getDetailedItemList()
    local targetItems = target:getDetailedItemList()

    -- [todo] hardcoded output slot range
    for targetSlot = 10, 27 do
        local targetItem = targetItems[targetSlot]

        if targetItem ~= nil then
            local stock = requiredInputStock[targetItem.name]

            if stock ~= nil and stock < 0 then
                -- we do have it in source chest, and we do have more than input needs, so we can push that to output
                local numToTransfer = math.min(targetItem:numMissing(), math.abs(stock))
                -- local numToTransfer = targetItem:numMissing()

                for sourceSlot, sourceItem in pairs(sourceItems) do
                    if sourceItem.count > 0 and sourceItem:equals(targetItem) then
                        print("push", sourceSlot, numToTransfer, targetSlot)
                        local numTransferred = source:pushItems(target.side, sourceSlot, numToTransfer, targetSlot)
                        sourceItem.count = sourceItem.count - numTransferred
                        numToTransfer = numToTransfer - numTransferred
                        requiredInputStock[targetItem.name] = requiredInputStock[targetItem.name] + numTransferred
                    end

                    if numToTransfer <= 0 then
                        break
                    end
                end
            end
        end
    end

    -- take input
    -- [todo] hardcoded input slot range
    for targetSlot = 1, 9 do
        local targetItem = targetItems[targetSlot]

        if targetItem ~= nil then
            local stock = requiredInputStock[targetItem.name]

            if stock ~= nil and stock > 0 then
                local numToTransfer = math.min(targetItem.count - 1, stock)
                local numTransferred = source:pullItems(target.side, targetSlot, numToTransfer)
                requiredInputStock[targetItem.name] = requiredInputStock[targetItem.name] - numTransferred
            end
        end
    end
end

local function main(args)
    local bufferBarrel = KiwiChest.new(KiwiPeripheral.findSide("minecraft:barrel"))
    local ioChest = KiwiChest.new(KiwiPeripheral.findSide("minecraft:chest"))
    doTheThing(bufferBarrel, ioChest)
end

return main(arg)
