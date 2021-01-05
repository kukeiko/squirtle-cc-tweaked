package.path = package.path .. ";/libs/?.lua"

local Resources = {}

local function reduceAmount(a, b)
    local open = a - b

    if open <= 0 then
        return nil
    else
        return open
    end
end

local reducers = function()
    return {
        fuelLevel = reduceAmount,
        inventorySlot = reduceAmount,
        consumeItem = function(a, b)
            local emptyKeys = {}

            for i = 1, #b do
                local name = b[i].name
                local numLeft = b[i].count

                for e = 1, #a do
                    if a[e].name == name and a[e].count > 0 then
                        local numUsed = math.min(b[i].count, a[e].count)
                        a[e].count = a[e].count - numUsed

                        if a[e].count == 0 then
                            table.insert(emptyKeys, e)
                        end

                        numLeft = numLeft - numUsed

                        if numLeft == 0 then
                            break
                        end
                    end
                end
            end

            for i = #emptyKeys, 1, -1 do
                table.remove(a, emptyKeys[i])
            end

            if #a == 0 then
                return nil
            else
                return a
            end
        end
    }
end

function Resources.reduce(a, b)
    for resource, value in pairs(b) do
        if a[resource] ~= nil then
            local reducer = reducers()[resource]

            if not reducer then
                error("no reducer for resource '" .. resource .. "'")
            end

            a[resource] = reducer(a[resource], value)
        end
    end

    for _, v in pairs(a) do
        if v ~= nil then
            return a
        end
    end

    return nil
end

return Resources
