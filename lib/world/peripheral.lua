local Side = require "elements.side"
local native = peripheral
---@class Peripheral
local Peripheral = {}

---@param types string[]|string
---@param sides? string[]
---@return integer
function Peripheral.findSide(types, sides)
    if type(types) == "string" then
        types = {types}
    end

    sides = sides or Side.all()

    for i = 1, #sides do
        local foundType = Peripheral.getType(sides[i])

        if foundType ~= nil then
            for e = 1, #types do
                if foundType == types[e] then
                    return sides[i], types[e]
                end
            end
        end
    end
end

function Peripheral.isModem(side)
    return Peripheral.getType(side) == "modem"
end

function Peripheral.isWirelessModem(side)
    return Peripheral.isModem(side) and Peripheral.call(side, "isWireless")
end

function Peripheral.isWorkbench(side)
    return Peripheral.getType(side) == "workbench"
end

function Peripheral.wrapOne(types, sides)
    sides = sides or Side.all()

    for i = 1, #sides do
        local foundType = Peripheral.getType(sides[i])

        if foundType ~= nil then
            for e = 1, #types do
                if foundType == types[e] then
                    return Peripheral.wrap(sides[i]), sides[i], types[e]
                end
            end
        end
    end
end

function Peripheral.wrap(side)
    return native.wrap(Side.getName(side))
end

function Peripheral.isPresent(side)
    return native.isPresent(Side.getName(side))
end

function Peripheral.getType(side)
    return native.getType(Side.getName(side))
end

---@param side string|integer
function Peripheral.call(side, ...)
    if type(side) == "number" then
        side = Side.getName(side)
    end

    return native.call(side, ...)
end

function Peripheral.wrapOneContainer(sides)
    sides = sides or Side.all()

    for i = 1, #sides do
        local candidate = native.wrap(sides[i])

        if candidate ~= nil and Peripheral.isContainer(candidate) then
            return Peripheral.wrap(sides[i]), sides[i]
        end
    end
end

function Peripheral.isContainer(peripheral)
    return type(peripheral.getItemDetail) == "function"
end

function Peripheral.isContainerPresent(side)
    return Peripheral.isPresent(side) and Peripheral.isContainer(Peripheral.wrap(side))
end

return Peripheral
