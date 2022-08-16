local Side = require "squirtle.libs.side"
local Cardinal = require "squirtle.libs.cardinal"
local Vector = require "squirtle.libs.vector"
local Utils = require "squirtle.libs.utils"
local Peripheral = require "squirtle.libs.peripheral"

local native = turtle
local Turtle = {}

setmetatable(Turtle, {__index = native})

local nativeSidebasedHandlers = {
    attack = {
        [Side.top] = native.attackUp,
        [Side.front] = native.attack,
        [Side.bottom] = native.attackDown
    },
    compare = {
        [Side.top] = native.compareUp,
        [Side.front] = native.compare,
        [Side.bottom] = native.compareDown
    },
    detect = {
        [Side.top] = native.detectUp,
        [Side.front] = native.detect,
        [Side.bottom] = native.detectDown
    },
    dig = {[Side.top] = native.digUp, [Side.front] = native.dig, [Side.bottom] = native.digDown},
    drop = {[Side.top] = native.dropUp, [Side.front] = native.drop, [Side.bottom] = native.dropDown},
    inspect = {
        [Side.top] = native.inspectUp,
        [Side.front] = native.inspect,
        [Side.bottom] = native.inspectDown
    },
    place = {
        [Side.top] = native.placeUp,
        [Side.front] = native.place,
        [Side.bottom] = native.placeDown
    },
    suck = {[Side.top] = native.suckUp, [Side.front] = native.suck, [Side.bottom] = native.suckDown},
    move = {
        [Side.top] = native.up,
        [Side.front] = native.forward,
        [Side.bottom] = native.down,
        [Side.back] = native.back
    },
    turn = {[Side.left] = native.turnLeft, [Side.right] = native.turnRight}
}

local function callNativeSideBasedMethod(name, side, arg)
    local handlers = nativeSidebasedHandlers[name]

    if not handlers then
        error("no native handlers found for " .. name)
    end

    local handler = handlers[Side.fromArg(side or Side.front)]

    if not handler then
        error(name .. " does not support side " .. side)
    end

    return handler(arg)
end

function Turtle.attackAt(side, toolSide)
    return callNativeSideBasedMethod("attack", side, toolSide)
end

function Turtle.compareAt(side)
    return callNativeSideBasedMethod("compare", side)
end

function Turtle.detectAt(side)
    return callNativeSideBasedMethod("detect", side)
end

function Turtle.detectAll()
    local sides = {Side.top, Side.front, Side.bottom}
    local detections = {}

    for _, side in pairs(sides) do
        detections[side] = Turtle.detectAt(side)
    end

    return detections
end

function Turtle.digAt(side, toolSide)
    return callNativeSideBasedMethod("dig", side, toolSide)
end

function Turtle.dropAt(side, count)
    return callNativeSideBasedMethod("drop", side, count)
end

---@param side integer
function Turtle.inspectAt(side)
    return callNativeSideBasedMethod("inspect", side)
end

function Turtle.getBlockAt(side)
    local success, block = Turtle.inspectAt(side)

    if not success then
        return nil
    else
        return block
    end
end

function Turtle.inspectAll()
    local sides = {Side.top, Side.front, Side.bottom}
    local inspections = {}

    for _, side in pairs(sides) do
        inspections[side] = Turtle.getBlockAt(side)
    end

    return inspections
end

function Turtle.inspectDown()
    return callNativeSideBasedMethod("inspect", Side.bottom)
end

function Turtle.inspectUp()
    return callNativeSideBasedMethod("inspect", Side.top)
end

---@param signText? string
function Turtle.placeAt(side, signText)
    return callNativeSideBasedMethod("place", side, signText)
end

---@param signText? string
---@return boolean
function Turtle.place(signText)
    return callNativeSideBasedMethod("place", Side.front, signText)
end

function Turtle.suckAt(side, count)
    return callNativeSideBasedMethod("suck", side, count)
end

function Turtle.move(side)
    return callNativeSideBasedMethod("move", side)
end

function Turtle.forward()
    return Turtle.move(Side.front)
end

function Turtle.back()
    return Turtle.move(Side.back)
end

function Turtle.up()
    return Turtle.move(Side.top)
end

function Turtle.down()
    return Turtle.move(Side.bottom)
end

function Turtle.turn(side)
    if side == Side.back then
        if math.random() < 0.5 then
            if not Turtle.turnLeft() then
                return false
            end
            return Turtle.turnLeft()
        else
            if not Turtle.turnRight() then
                return false
            end
            return Turtle.turnRight()
        end
    else
        return callNativeSideBasedMethod("turn", side)
    end
end

function Turtle.turnAround()
    return Turtle.turn(Side.back)
end

function Turtle.turnLeft()
    return Turtle.turn(Side.left)
end

function Turtle.turnRight()
    return Turtle.turn(Side.right)
end

---@param current number
---@param target number
function Turtle.turnToCardinal(current, target)
    if (current + 2) % 4 == target then
        Turtle.turnAround()
    elseif (current + 1) % 4 == target then
        Turtle.turnRight()
    elseif (current - 1) % 4 == target then
        Turtle.turnLeft()
    end

    return target
end

-- todo: this method is not basic enough to stay in the Turtle API.
-- but i have no idea yet where to put such a method, so for now it is here.
function Turtle.orientate()
    if not Turtle.hasFuel(2) then
        error("not enough fuel to orientate")
    end

    local position = Turtle.getPosition()

    if Turtle.forward() then
        local now = Turtle.getPosition()
        local cardinal = Cardinal.fromVector(now:minus(position))

        while not Turtle.back() do
            print("can't move back, something is blocking me. sleeping 1s...")
            os.sleep(1)
        end

        return cardinal, position
    elseif Turtle.back() then
        local now = Turtle.getPosition()
        local cardinal = Cardinal.fromVector(now:minus(position))

        while not Turtle.forward() do
            print("can't move forwards, something is blocking me. sleeping 1s...")
            os.sleep(1)
        end

        return Cardinal.rotateAround(cardinal), position
    else
        Turtle.turnLeft()

        if Turtle.forward() then
            local now = Turtle.getPosition()
            local cardinal = Cardinal.fromVector(now:minus(position))

            while not Turtle.back() do
                print("can't move back, something is blocking me. sleeping 1s...")
                os.sleep(1)
            end

            Turtle.turnRight()

            return Cardinal.rotateRight(cardinal), position
        elseif Turtle.back() then
            local now = Turtle.getPosition()
            local cardinal = Cardinal.fromVector(now:minus(position))

            while not Turtle.forward() do
                print("can't move forwards, something is blocking me. sleeping 1s...")
                os.sleep(1)
            end

            Turtle.turnRight()

            return Cardinal.rotateLeft(cardinal), position
        else
            Turtle.turnRight()
            error("failed to orientate - possibly blocked in on all sides or no fuel")
        end
    end
end

function Turtle.getPosition()
    local x, y, z = gps.locate()

    if x == nil then
        error("gps not available")
    end

    return Vector.new(x, y, z)
end

function Turtle.moveAggressive(side, times)
    side = Side.fromArg(side) or Side.front
    times = times or 1

    for _ = 1, times do
        while not Turtle.move(side) do
            if Turtle.detectAt(side) then
                Turtle.digAt(side)
            else
                Turtle.attackAt(side)
            end
        end
    end
end

---@param point Vector
function Turtle.moveToPointAggressive(point)
    local current = Turtle.getPosition()
    local delta = point:minus(current)
    local orientation = Turtle.orientate()

    if delta.y > 0 then
        Turtle.moveAggressive(Side.top, delta.y)
    elseif delta.y < 0 then
        Turtle.moveAggressive(Side.bottom, delta.y * -1)
    end

    if delta.x > 0 then
        Turtle.turnToCardinal(orientation, Cardinal.east)
        orientation = Cardinal.east
        Turtle.moveAggressive(Side.front, delta.x)
    elseif delta.x < 0 then
        Turtle.turnToCardinal(orientation, Cardinal.west)
        orientation = Cardinal.west
        Turtle.moveAggressive(Side.front, delta.x * -1)
    end

    if delta.z > 0 then
        Turtle.turnToCardinal(orientation, Cardinal.south)
        orientation = Cardinal.south
        Turtle.moveAggressive(Side.front, delta.z)
    elseif delta.z < 0 then
        Turtle.turnToCardinal(orientation, Cardinal.north)
        orientation = Cardinal.north
        Turtle.moveAggressive(Side.front, delta.z * -1)
    end
end

function Turtle.getFuelLevel()
    return native.getFuelLevel()
end

function Turtle.getFuelLimit()
    return native.getFuelLimit()
end

---@param limit? integer
function Turtle.getMissingFuel(limit)
    local fuelLevel = Turtle.getFuelLevel()

    if fuelLevel == "unlimited" then
        return 0
    end

    limit = limit or Turtle.getFuelLimit()

    return limit - Turtle.getFuelLevel()
end

function Turtle.hasFuel(level)
    local fuelLevel = Turtle.getFuelLevel()

    return fuelLevel == "unlimited" or fuelLevel >= level
end

---@param slot number
function Turtle.select(slot)
    return native.select(slot)
end

---@param count? number
function Turtle.refuel(count)
    return native.refuel(count)
end

function Turtle.tryMovePeaceful(side, times)
    times = times or 1

    -- self:getFueling():refuel(times)

    for i = 1, times do
        local success, e = Turtle.move(side)
        if not success then
            return false, i - 1, e
        end
    end

    return true, times
end

function Turtle.tryWalkPathPeaceful(path, location, facing)
    if (#path == 0) then
        return true, location, facing
    end

    -- local newLocation = location
    -- local newFacing = facing
    -- self:getFueling():refuel(#path)
    local success, times, side

    for _, v in ipairs(path) do
        local delta = v - location

        -- Utils.prettyPrint(delta)

        if (delta.x > 0) then
            facing = Turtle.turnToCardinal(facing, Cardinal.east)
            -- self:turnToOrientation(EAST)
            side = Side.front
            success, times = Turtle.tryMovePeaceful(side, delta.x)
            location = location + (Cardinal.toVector(Cardinal.east) * times)
        elseif (delta.x < 0) then
            -- self:turnToOrientation(WEST)
            facing = Turtle.turnToCardinal(facing, Cardinal.west)
            side = Side.front
            success, times = Turtle.tryMovePeaceful(side, delta.x * -1)
            location = location + (Cardinal.toVector(Cardinal.west) * times)
        elseif (delta.y > 0) then
            side = Side.top
            success, times = Turtle.tryMovePeaceful(side, delta.y)
            location = location + (Cardinal.toVector(Cardinal.up) * times)
        elseif (delta.y < 0) then
            side = Side.bottom
            success, times = Turtle.tryMovePeaceful(side, delta.y * -1)
            location = location + (Cardinal.toVector(Cardinal.down) * times)
        elseif (delta.z > 0) then
            -- self:turnToOrientation(SOUTH)
            side = Side.front
            facing = Turtle.turnToCardinal(facing, Cardinal.south)
            success, times = Turtle.tryMovePeaceful(side, delta.z)
            location = location + (Cardinal.toVector(Cardinal.south) * times)
        elseif (delta.z < 0) then
            -- self:turnToOrientation(NORTH)
            side = Side.front
            facing = Turtle.turnToCardinal(facing, Cardinal.north)
            success, times = Turtle.tryMovePeaceful(side, delta.z * -1)
            location = location + (Cardinal.toVector(Cardinal.north) * times)
        end

        -- location = v

        -- print("walk", success, location)

        if (not success) then
            return false, location, facing, side
        end
    end

    return success, location, facing
end

function Turtle.wrapLocalPeripherals()
    local peripherals = {
        top = Peripheral.wrap(Side.top),
        bottom = Peripheral.wrap(Side.bottom),
        front = Peripheral.wrap(Side.front),
        back = Peripheral.wrap(Side.back)
    }

    if Turtle.hasAnyPeripheralEquipped() then
        Turtle.turnLeft()
        peripherals.left = Peripheral.wrap(Side.front)
        peripherals.right = Peripheral.wrap(Side.back)
        Turtle.turnRight()
    else
        peripherals.left = Peripheral.wrap(Side.left)
        peripherals.right = Peripheral.wrap(Side.right)
    end

    return peripherals
end

function Turtle.hasAnyPeripheralEquipped()
    local sides = {Side.left, Side.right}

    for i = 1, #sides do
        if Peripheral.isWorkbench(sides[i]) then
            return true
        elseif Peripheral.isWirelessModem(sides[i]) then
            return true
        end
    end

    return false
end

return Turtle
