local Chest = require "world.chest"

---@param source integer
---@param target integer
return function(source, target)
    local sourceItems = Chest.getStacks(source, true)

    for inputSlot, inputStack in pairs(Chest.getInputStacks(target, true)) do
        if inputStack.count < inputStack.maxCount then
            local numMissing = inputStack.maxCount - inputStack.count

            for sourceSlot, sourceItem in pairs(sourceItems) do
                if sourceItem.count > 0 and sourceItem.name == inputStack.name then
                    local transfer = math.min(sourceItem.count, numMissing)
                    local transferred = Chest.pushItems(source, target, sourceSlot, transfer, inputSlot)
                    sourceItem.count = sourceItem.count - transferred
                    numMissing = numMissing - transferred
                end

                if numMissing <= 0 then
                    break
                end
            end
        end
    end
end
