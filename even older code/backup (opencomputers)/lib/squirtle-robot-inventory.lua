-- 0.1.0
local robot = require("robot")

local api = {}

function api.getSize()
    return robot.inventorySize()
end

function api.isEmpty()
    for i = 1, robot.inventorySize() do
        if robot.count(i) > 0 then
            return false
        end
    end

    return true
end

function api.isFull()
    for i = 1, robot.inventorySize() do
        if robot.count(i) == 0 then
            return false
        end
    end

    return true
end

function api.dump()
    for i = 1, robot.inventorySize() do
        if robot.count(i) > 0 then
            robot.select(i)
            robot.drop()
        end
    end
end

return api
