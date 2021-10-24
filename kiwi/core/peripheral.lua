local Side = require "kiwi.core.side"
local native = peripheral
---@class KiwiPeripheral
local KiwiPeripheral = {}

function KiwiPeripheral.getSide(types, sides)
    sides = sides or Side.all()

    for i = 1, #sides do
        local foundType = KiwiPeripheral.getType(sides[i])

        if foundType ~= nil then
            for e = 1, #types do
                if foundType == types[e] then
                    return sides[i], types[e]
                end
            end
        end
    end
end

function KiwiPeripheral.isModem(side)
    return KiwiPeripheral.getType(side) == "modem"
end

function KiwiPeripheral.isWirelessModem(side)
    return KiwiPeripheral.isModem(side) and KiwiPeripheral.call(side, "isWireless")
end

function KiwiPeripheral.isWorkbench(side)
    return KiwiPeripheral.getType(side) == "workbench"
end

function KiwiPeripheral.wrapOne(types, sides)
    sides = sides or Side.all()

    for i = 1, #sides do
        local foundType = KiwiPeripheral.getType(sides[i])

        if foundType ~= nil then
            for e = 1, #types do
                if foundType == types[e] then
                    return KiwiPeripheral.wrap(sides[i]), sides[i], types[e]
                end
            end
        end
    end
end

function KiwiPeripheral.wrap(side)
    return native.wrap(Side.getName(side))
end

function KiwiPeripheral.isPresent(side)
    return native.isPresent(Side.getName(side))
end

function KiwiPeripheral.getType(side)
    return native.getType(Side.getName(side))
end

function KiwiPeripheral.call(side, ...)
    return native.call(Side.getName(side), ...)
end

function KiwiPeripheral.wrapOneContainer(sides)
    sides = sides or Side.all()

    for i = 1, #sides do
        local candidate = native.wrap(sides[i])

        if candidate ~= nil and KiwiPeripheral.isContainer(candidate) then
            return KiwiPeripheral.wrap(sides[i]), sides[i]
        end
    end
end

function KiwiPeripheral.isContainer(peripheral)
    return type(peripheral.getItemDetail) == "function"
end

function KiwiPeripheral.isContainerPresent(side)
    return KiwiPeripheral.isPresent(side) and KiwiPeripheral.isContainer(KiwiPeripheral.wrap(side))
end

return KiwiPeripheral
