package.path = package.path .. ";/libs/?.lua"

local Sides = require "sides"

local Peripheral = {}

setmetatable(Peripheral, {__index = peripheral})

function Peripheral.getSide(types, sides)
    sides = sides or Sides.all()

    for i = 1, #sides do
        local foundType = peripheral.getType(sides[i])

        if foundType ~= nil then
            for e = 1, #types do
                if foundType == types[e] then
                    return sides[i], types[e]
                end
            end
        end
    end
end

function Peripheral.wrapOne(types, sides)
    sides = sides or Sides.all()

    for i = 1, #sides do
        local foundType = peripheral.getType(sides[i])

        if foundType ~= nil then
            for e = 1, #types do
                if foundType == types[e] then
                    return peripheral.wrap(sides[i]), sides[i], types[e]
                end
            end
        end
    end
end

function Peripheral.wrapOneContainer(sides)
    sides = sides or Sides.all()

    for i = 1, #sides do
        local candidate = peripheral.wrap(sides[i])

        if candidate ~= nil and type(candidate.getItemDetail) == "function" then
            return peripheral.wrap(sides[i]), sides[i]
        end
    end
end

return Peripheral
