local Chest = require "world.chest"

---@param source integer
---@param target integer
return function(source, target)
    local sourceItems = Chest.getStacks(source, true)
    local targetItems = Chest.getStacks(target, true)
    local targetInstance = Chest.new(target)

    for targetSlot = targetInstance:getFirstInputSlot(), targetInstance:getLastInputSlot() do
        local targetItem = targetItems[targetSlot]

        if targetItem ~= nil and targetItem.count < targetItem.maxCount then
            local numMissing = targetItem.maxCount - targetItem.count

            for sourceSlot, sourceItem in pairs(sourceItems) do
                if sourceItem.count > 0 and sourceItem.name == targetItem.name then
                    -- [todo] dont think we really need to take min here. just take numMissing.
                    local numToTransfer = math.min(sourceItem.count, numMissing)
                    local numTransferred = Chest.pushItems(source, target, sourceSlot, numToTransfer, targetSlot)
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
