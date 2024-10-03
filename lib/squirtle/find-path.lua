local World = require "lib.common.world"
local Cardinal = require "lib.common.cardinal"
local Vector = require "lib.common.vector"

---@param hierarchy Vector[]
---@param start Vector
---@param goal Vector
local function toPath(hierarchy, start, goal)
    local path = {}
    local next = goal

    while not Vector.equals(next, start) do
        table.insert(path, 1, next)
        next = hierarchy[Vector.toString(next)]
    end

    return path
end

---@param open Vector[]
---@param naturals Vector[]
---@param forced Vector[]
---@param pruned Vector[]
---@param totalCost number[]
local function findBest(open, naturals, forced, pruned, totalCost)
    local lowestF = nil
    local bestType = nil

    ---@type Vector
    local best = nil

    for key, value in pairs(open) do
        local type = 3

        if naturals[key] then
            type = 0
        elseif forced[key] then
            type = 1
        elseif pruned[key] then
            type = 2
        end

        if lowestF == nil or totalCost[key] < lowestF or (totalCost[key] <= lowestF and type < bestType) then
            best = value
            lowestF = totalCost[key]
            bestType = type
        end
    end

    return best
end

---@param start Vector
---@param goal Vector
---@param orientation integer
---@param world? World
return function(start, goal, orientation, world)
    if not world then
        world = World.create(start.x, start.y, start.z)
    end

    if World.isBlocked(world, goal) then
        return false, "goal is blocked"
    end

    ---@type Vector[]
    local open = {}
    local numOpen = 0
    local closed = {}

    ---@type Vector[]
    local reverseMap = {}
    local pastCost = {}
    local futureCost = {}
    local totalCost = {}
    local startKey = Vector.toString(start)
    local naturals = {}
    local forced = {}
    local pruned = {}

    open[startKey] = start
    pastCost[startKey] = 0
    futureCost[startKey] = Vector.manhattan(start, goal)
    totalCost[startKey] = pastCost[startKey] + futureCost[startKey]
    numOpen = numOpen + 1

    local cycles = 0
    local timeStarted = os.clock()
    local timeout = 3

    while (numOpen > 0) do
        cycles = cycles + 1

        if cycles % 100 == 0 then
            if os.clock() - timeStarted >= timeout then
                return false, timeout .. "s timeout reached"
            end

            -- [todo] make event name more unique to prevent collisions?
            os.queueEvent("a-star-progress")
            os.pullEvent("a-star-progress")
        end

        local current = findBest(open, naturals, forced, pruned, totalCost)

        if Vector.equals(current, goal) then
            return toPath(reverseMap, start, goal)
        end

        local currentKey = Vector.toString(current)

        open[currentKey] = nil
        closed[currentKey] = current
        numOpen = numOpen - 1

        if reverseMap[currentKey] then
            local delta = Vector.minus(current, reverseMap[currentKey])
            orientation = Cardinal.fromVector(delta)
        end

        local neighbours = {}

        for i = 0, 5 do
            local neighbour = Vector.plus(current, Cardinal.toVector(i))
            local neighbourKey = Vector.toString(neighbour)
            local requiresTurn = false

            if i ~= orientation and not Cardinal.isVertical(i) then
                requiresTurn = true
            end

            if closed[neighbourKey] == nil and World.isInBounds(world, neighbour) and not World.isBlocked(world, neighbour) then
                local tentativePastCost = pastCost[currentKey] + 1

                if (requiresTurn) then
                    tentativePastCost = tentativePastCost + 1
                end

                if open[neighbourKey] == nil or tentativePastCost < pastCost[neighbourKey] then
                    pastCost[neighbourKey] = tentativePastCost

                    local neighbourFutureCost = Vector.manhattan(neighbour, goal)

                    if (neighbour.x ~= goal.x) then
                        neighbourFutureCost = neighbourFutureCost + 1
                    end
                    if (neighbour.z ~= goal.z) then
                        neighbourFutureCost = neighbourFutureCost + 1
                    end
                    if (neighbour.y ~= goal.y) then
                        neighbourFutureCost = neighbourFutureCost + 1
                    end

                    futureCost[neighbourKey] = neighbourFutureCost
                    totalCost[neighbourKey] = pastCost[neighbourKey] + neighbourFutureCost
                    reverseMap[neighbourKey] = current

                    if (open[neighbourKey] == nil) then
                        open[neighbourKey] = neighbour
                        neighbours[i] = neighbour
                        numOpen = numOpen + 1
                    end
                end
            end
        end

        -- pruning
        if (reverseMap[currentKey] ~= nil) then
            for neighbourOrientation, neighbour in pairs(neighbours) do
                local neighbourKey = Vector.toString(neighbour)

                if (neighbourOrientation == orientation) then
                    -- add natural neighbour
                    naturals[neighbourKey] = neighbour
                else
                    -- check blockade
                    local check = Vector.plus(reverseMap[currentKey],
                                              Vector.minus(Cardinal.toVector(neighbourOrientation), Cardinal.toVector(orientation)))

                    -- if (world[checkKey] == nil) then
                    if not World.isBlocked(world, check) then
                        -- add neighbour to prune
                        pruned[neighbourKey] = neighbour
                    else
                        -- add neighbour to forced
                        forced[neighbourKey] = neighbour
                    end
                end
            end
        end
    end

    return false, "no path available"
end
