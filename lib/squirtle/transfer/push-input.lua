---@param source Chest
---@param target Chest
return function(source, target)
    local sourceItems = source:getDetailedItemList()
    local targetItems = target:getDetailedItemList()

    for targetSlot = target:getFirstInputSlot(), target:getLastInputSlot() do
        local targetItem = targetItems[targetSlot]

        if targetItem ~= nil and targetItem:numMissing() > 0 then
            local numMissing = targetItem:numMissing()

            for sourceSlot, sourceItem in pairs(sourceItems) do
                -- checking for > 0 as we mutate it in place instead of removing entry
                -- from table as im not sure if that would work bug-free
                if sourceItem.count > 0 and sourceItem:equals(targetItem) then
                    -- [todo] dont think we really need to take min here. just take numMissing.
                    local numToTransfer = math.min(sourceItem.count, numMissing)
                    local numTransferred = source:pushItems(target.side, sourceSlot, numToTransfer, targetSlot)
                    sourceItem.count = sourceItem.count - numTransferred
                    numMissing = numMissing - numTransferred
                end

                if numMissing <= 0 then
                    break
                end
            end
        end
    end
end
