package.path = package.path .. ";/libs/?.lua"

local Container = {}

function Container.countItems(stacks)
    local numItems = 0

    for _, stack in pairs(stacks) do
        numItems = numItems + stack.count
    end

    return numItems
end

return Container
