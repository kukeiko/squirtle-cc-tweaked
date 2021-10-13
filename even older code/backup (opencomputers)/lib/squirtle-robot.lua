-- 0.1.0
local robot = require("robot")
local sides = require("squirtle-sides")

local api = {
    -- by default we'll assume robots without a nav upgrade are facing south on startup
    _facing = sides.south
}

setmetatable(api, { __index = robot })

function api.forward(times)
    times = times or 1

    for i = 1, times do
        local moved, reason = robot.forward()

        if not moved then
            return moved, reason, i - 1
        end
    end

    return true, nil, times
end

function api.back(times)
    times = times or 1

    for i = 1, times do
        local moved, reason = robot.back()

        if not moved then
            return moved, reason, i - 1
        end
    end

    return true, nil, times
end

function api.getFacing()
    return api._facing
end

function api.turnLeft()
    local result = { robot.turnLeft() }
    if not result[1] then return table.unpack(result) end

    api._facing = sides.turn.left[api._facing]

    return true
end

function api.turnRight()
    local result = { robot.turnRight() }
    if not result[1] then return table.unpack(result) end

    api._facing = sides.turn.right[api._facing]

    return true
end

function api.turnAround()
    local result = { robot.turnAround() }
    if not result[1] then return table.unpack(result) end

    api._facing = sides.turn.around[api._facing]

    return true
end

function api.turnTo(side)
    if(api._facing == side) then
        return true
    elseif(sides.turn.left[api._facing] == side) then
        return api.turnLeft()
    elseif(sides.turn.right[api._facing] == side) then
        return api.turnRight()
    elseif(sides.turn.around[api._facing] == side) then
        return api.turnAround()
    end

    return true
end

return api
