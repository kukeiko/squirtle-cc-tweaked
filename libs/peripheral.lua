package.path = package.path .. ";/libs/?.lua"

local Sides = require "sides"

local Peripheral = {}

setmetatable(Peripheral, {__index = peripheral})

function Peripheral.wrapContainer(sides)
    sides = sides or Sides.all()

    for i = 1, #sides do
        local candidate = peripheral.wrap(sides[i])

        if candidate ~= nil and type(candidate.getItemDetail) == "function" then
            return peripheral.wrap(sides[i]), sides[i]
        end
    end
end

return Peripheral
