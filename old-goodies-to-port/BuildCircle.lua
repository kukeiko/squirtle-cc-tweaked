-- [todo] this app looks complete, and it even sorts blocks to place by distance,
-- so that it has an optimized path. need to port it to new lib and test it out!
local BuildCircle = {}

--- <summary>
--- </summary>
--- <returns type="BuildCircle"></returns>
function BuildCircle.new()
    local instance = {}
    setmetatable(instance, {__index = BuildCircle})
    instance:ctor()

    return instance
end

function BuildCircle:ctor()
end

function BuildCircle:run()
    MessagePump.run()

    local squirtle = System.Squirtle.new()
    local pickaxe = Components.Squirtle.Pickaxe.cast(squirtle:base():loadComponent("Squirtle.Pickaxe"))
    local movement = Components.Squirtle.Movement.cast(squirtle:base():loadComponent("Squirtle.Movement"))
    local fuel = Components.Squirtle.Fueling.cast(squirtle:base():loadComponent("Squirtle.Fueling"))
    local inv = Components.Squirtle.Inventory.cast(squirtle:base():loadComponent("Squirtle.Inventory"))
    local loc = Components.Location.cast(squirtle:base():loadComponent("Location"))

    local ui = UI.ConsoleUI.new()

    local radius = ui:getInt("Radius?")
    local height = ui:getInt("Height?")
    local points = self:getCirclePoints(loc:getLocation(), radius)
    local offset = 0

    for e = 1, height do
        for i = 1, #points do
            local point = points[i]
            point.y = point.y + offset
            movement:moveToAggressive(point)
            inv:select(inv:findItem())
            squirtle:place(DOWN)
        end

        offset = offset + 1
    end

    MessagePump.pull("key")
end

function BuildCircle:sortPoints(points)
    local array = {}

    for k, v in pairs(points) do
        table.insert(array, points[k])
    end

    local vectorLength = function(p)
        return math.sqrt(p.x ^ 2 + p.y ^ 2 + p.z ^ 2)
    end

    local sorted = {}
    local point = array[1]
    table.insert(sorted, array[1])
    table.remove(array, 1)

    local shortestDistance = nil
    local shortestIndex = nil

    while (#array > 0) do
        for i = 1, #array do
            local other = array[i]
            local distance = vectorLength(other - point)

            if (shortestDistance == nil or distance < shortestDistance) then
                shortestDistance = distance
                shortestIndex = i
            end
        end

        shortestDistance = nil
        point = array[shortestIndex]
        table.insert(sorted, array[shortestIndex])
        table.remove(array, shortestIndex)
    end

    return sorted
end

function BuildCircle:getCirclePoints(start, radius)
    local points = {}
    local f = 1 - radius
    local ddf_x = 0
    local ddf_y = radius * -2
    local x = 0
    local y = radius

    local centerX = start.x
    local centerY = start.z

    local addPoint = function(x, y)
        local point = vector.new(x, start.y, y)
        points[point:tostring()] = point
    end

    addPoint(centerX, centerY + radius)
    addPoint(centerX, centerY - radius)
    addPoint(centerX + radius, centerY)
    addPoint(centerX - radius, centerY)

    while (x < y) do
        if (f >= 0) then
            y = y - 1
            ddf_y = ddf_y + 2
            f = f + ddf_y
        end

        x = x + 1
        ddf_x = ddf_x + 2
        f = f + ddf_x + 1

        addPoint(centerX + x, centerY + y)
        addPoint(centerX - x, centerY + y)
        addPoint(centerX + x, centerY - y)
        addPoint(centerX - x, centerY - y)

        addPoint(centerX + y, centerY + x)
        addPoint(centerX - y, centerY + x)
        addPoint(centerX + y, centerY - x)
        addPoint(centerX - y, centerY - x)
    end

    return self:sortPoints(points)
end

if (Apps == nil) then
    Apps = {}
end
Apps.BuildCircle = BuildCircle
