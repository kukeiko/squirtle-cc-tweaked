local protocol = "squirtle:fuel_provider"

local FuelProvider = {}

function FuelProvider.lookup()
    return rednet.lookup(protocol)
end

function FuelProvider.host()
    return rednet.host(protocol, "squirtle:" .. os.getComputerID())
end

---@param computerIds integer[]
---@param position Vector
---@param fuel integer
function FuelProvider.estimateFuelDelivery(computerIds, position, fuel)
    local results = {}
    local fns = {}

    for _, id in pairs(computerIds) do
        table.insert(fns, function()
            rednet.send(id, {method = "estimate", position = position, fuel = fuel})
            -- local response = rednet.receive()
        end)
    end
end

return FuelProvider
