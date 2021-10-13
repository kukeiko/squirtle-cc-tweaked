
local vector = {
    add = function(self, o)
        return new(
        self.x + o.x,
        self.y + o.y,
        self.z + o.z
        )
    end,
    sub = function(self, o)
        return new(
        self.x - o.x,
        self.y - o.y,
        self.z - o.z
        )
    end,
    mul = function(self, m)
        return new(
        self.x * m,
        self.y * m,
        self.z * m
        )
    end,
    div = function(self, m)
        return new(
        self.x / m,
        self.y / m,
        self.z / m
        )
    end,
    unm = function(self)
        return new(
        - self.x,
        - self.y,
        - self.z
        )
    end,
    dot = function(self, o)
        return self.x * o.x + self.y * o.y + self.z * o.z
    end,
    cross = function(self, o)
        return new(
        self.y * o.z - self.z * o.y,
        self.z * o.x - self.x * o.z,
        self.x * o.y - self.y * o.x
        )
    end,
    length = function(self)
        return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
    end,
    normalize = function(self)
        return self:mul(1 / self:length())
    end,
    round = function(self, nTolerance)
        nTolerance = nTolerance or 1.0
        return new(
        math.floor((self.x +(nTolerance * 0.5)) / nTolerance) * nTolerance,
        math.floor((self.y +(nTolerance * 0.5)) / nTolerance) * nTolerance,
        math.floor((self.z +(nTolerance * 0.5)) / nTolerance) * nTolerance
        )
    end,
    tostring = function(self)
        return self.x .. "," .. self.y .. "," .. self.z
    end,
}


function vector.equals(a, b)
    return a.x == b.x and a.y == b.y and a.z == b.z
end

local vmetatable = {
    __index = vector,
    __add = vector.add,
    __sub = vector.sub,
    __mul = vector.mul,
    __div = vector.div,
    __unm = vector.unm,
    __tostring = vector.tostring,
}

function new(x, y, z)
    local v = {
        x = x or 0,
        y = y or 0,
        z = z or 0
    }
    setmetatable(v, vmetatable)
    return v
end

SOUTH, WEST, NORTH, EAST, UP, DOWN = 0, 1, 2, 3, 4, 5
_G["SOUTH"] = SOUTH
_G["WEST"] = WEST
_G["NORTH"] = NORTH
_G["EAST"] = EAST
_G["UP"] = UP
_G["DOWN"] = DOWN

ORIENTATIONS = {
    [SOUTH] = "south",
    [WEST] = "west",
    [NORTH] = "north",
    [EAST] = "east",
    [UP] = "up",
    [DOWN] = "down",
    ["Deltas"] =
    {
        [SOUTH] = new(0,0,1),
        [WEST] = new(-1,0,0),
        [NORTH] = new(0,0,- 1),
        [EAST] = new(1,0,0),
        [UP] = new(0,1,0),
        [DOWN] = new(0,- 1,0),
        ["0,0,1"] = SOUTH,
        ["-1,0,0"] = WEST,
        ["0,0,-1"] = NORTH,
        ["1,0,0"] = EAST,
        ["0,1,0"] = UP,
        ["0,-1,0"] = DOWN
    }
}

_G["ORIENTATIONS"] = ORIENTATIONS

if (turtle) then
    FRONT, RIGHT, BACK, LEFT, TOP, BOTTOM = 0, 1, 2, 3, 4, 5
else
    FRONT, RIGHT, BACK, LEFT, TOP, BOTTOM = 0, 3, 2, 1, 4, 5
end

_G["FRONT"] = FRONT
_G["RIGHT"] = RIGHT
_G["BACK"] = BACK
_G["LEFT"] = LEFT
_G["TOP"] = TOP
_G["BOTTOM"] = BOTTOM

SIDES = {
    [FRONT] = "front",
    ["front"] = FRONT,
    [LEFT] = "left",
    ["left"] = LEFT,
    [BACK] = "back",
    ["back"] = BACK,
    [RIGHT] = "right",
    ["right"] = RIGHT,
    [TOP] = "top",
    ["top"] = TOP,
    [BOTTOM] = "bottom",
    ["bottom"] = BOTTOM
}

_G["SIDES"] = SIDES


Pathing = { }

local self = Pathing

function Pathing.manhattan(v0, v1)
    return math.abs(v1.x - v0.x) + math.abs(v1.y - v0.y) + math.abs(v1.z - v0.z)
end

function Pathing.aStar(world, start, goal, orientation)
    if (world[goal:tostring()] ~= nil) then return nil end

    orientation = orientation or SOUTH

    local open = { }
    local numOpen = 0
    local closed = { }
    local map = { }
    local pastCost = { }
    local futureCost = { }
    local totalCost = { }
    local estimatedSteps = self.manhattan(start, goal)
    local heuristic = self.manhattan
    local startKey = start:tostring()

    open[startKey] = start
    pastCost[startKey] = 0
    futureCost[startKey] = heuristic(start, goal)
    totalCost[startKey] = pastCost[startKey] + futureCost[startKey]
    numOpen = numOpen + 1

    while (numOpen > 0) do
        local lowestF = nil
        local current = nil
        local currentKey = nil

        for k, v in pairs(open) do
            if (lowestF == nil or totalCost[k] < lowestF) then
                current = v
                currentKey = k
                lowestF = totalCost[k]
            end
        end

        if (vector.equals(current, goal)) then
            local path = { }
            local pathVector = goal

            while (not vector.equals(pathVector, start)) do
                table.insert(path, pathVector)
                pathVector = map[pathVector:tostring()]
            end

            local revPath = { }

            for k, v in pairs(path) do
                table.insert(revPath, 1, v)
            end

            return revPath
        end

        open[currentKey] = nil
        closed[currentKey] = current
        numOpen = numOpen - 1

        if (map[currentKey]) then
            local delta = current - map[currentKey]
            orientation = ORIENTATIONS.Deltas[delta:tostring()]
        end

        local neighbours = { }

        for i = 0, #ORIENTATION_DELTAS do
            local neighbour = current + ORIENTATION_DELTAS[i]
            local neighbourKey = neighbour:tostring()
            local requiresTurn = false

            if (i ~= orientation and i ~= UP and i ~= DOWN) then
                requiresTurn = true
            end

            if (closed[neighbourKey] == nil and world[neighbourKey] == nil) then
                local tentativePastCost = pastCost[currentKey] + 1

                if (requiresTurn) then
                    tentativePastCost = tentativePastCost + 1
                end

                if (open[neighbourKey] == nil or tentativePastCost < pastCost[neighbourKey]) then
                    pastCost[neighbourKey] = tentativePastCost

                    local neighbourFutureCost = heuristic(neighbour, goal)

                    -- future turn costs
                    if (neighbour.x ~= goal.x) then neighbourFutureCost = neighbourFutureCost + 1 end
                    if (neighbour.z ~= goal.z) then neighbourFutureCost = neighbourFutureCost + 1 end

                    futureCost[neighbourKey] = neighbourFutureCost
                    totalCost[neighbourKey] = pastCost[neighbourKey] + neighbourFutureCost

                    map[neighbourKey] = current

                    if (open[neighbourKey] == nil) then
                        open[neighbourKey] = neighbour
                        numOpen = numOpen + 1
                    end
                end
            end
        end

        coroutine.yield(numOpen, estimatedSteps)
    end

    return nil
end

function Pathing.aStarPruning(world, start, goal, orientation)
    if (world[goal:tostring()] ~= nil) then return nil end

    orientation = orientation or SOUTH

    local open = { }
    local numOpen = 0
    local closed = { }
    local map = { }
    local pastCost = { }
    local futureCost = { }
    local totalCost = { }
    local heuristic = self.manhattan
    local startKey = start:tostring()
    local naturals = { }
    local forced = { }
    local pruned = { }

    local highestFutureCost = nil
    local lowestFutureCost = nil

    open[startKey] = start
    pastCost[startKey] = 0
    futureCost[startKey] = heuristic(start, goal)
    totalCost[startKey] = pastCost[startKey] + futureCost[startKey]
    numOpen = numOpen + 1

    while (numOpen > 0) do
        local lowestF = nil
        local current = nil
        local currentKey = nil
        local currentType = nil

        for k, v in pairs(open) do
            local thisType = 3

            if (naturals[k]) then
                thisType = 0
            elseif (forced[k]) then
                thisType = 1
            elseif (pruned[k]) then
                thisType = 2
            end

            if (highestFutureCost == nil or futureCost[k] > highestFutureCost) then
                highestFutureCost = futureCost[k]
            end

            if (lowestFutureCost == nil or futureCost[k] < lowestFutureCost) then
                lowestFutureCost = futureCost[k]
            end

            if (lowestF == nil or totalCost[k] < lowestF) then
                current = v
                currentKey = k
                lowestF = totalCost[k]
                currentType = thisType
            elseif (totalCost[k] <= lowestF and thisType < currentType) then
                current = v
                currentKey = k
                lowestF = totalCost[k]
                currentType = thisType
            end
        end

        if (vector.equals(current, goal)) then
            --            local progress = math.ceil(math.abs((lowestFutureCost / highestFutureCost) -1) * 100)
            --            coroutine.yield(progress)

            local path = { }
            local pathVector = goal

            while (not vector.equals(pathVector, start)) do
                table.insert(path, pathVector)
                pathVector = map[pathVector:tostring()]
            end

            local revPath = { }
            for k, v in pairs(path) do table.insert(revPath, 1, v) end

            -- print("[Naturals]: "..table.size(naturals))
            -- print("[Forced]: "..table.size(forced))
            -- print("[Pruned]: "..table.size(pruned))
            -- print("[Closed]: "..table.size(closed))

            return revPath
        end

        open[currentKey] = nil
        closed[currentKey] = current
        numOpen = numOpen - 1

        if (map[currentKey]) then
            local delta = current - map[currentKey]
            orientation = ORIENTATIONS.Deltas[delta:tostring()]
        end

        local neighbours = { }

        for i = 0, 5 do
            local neighbour = current + ORIENTATIONS.Deltas[i]
            local neighbourKey = neighbour:tostring()
            local requiresTurn = false

            if (i ~= orientation and(i ~= UP or i ~= DOWN)) then
                requiresTurn = true
            end

            if (closed[neighbourKey] == nil and world[neighbourKey] == nil) then
                local tentativePastCost = pastCost[currentKey] + 1

                if (requiresTurn) then
                    tentativePastCost = tentativePastCost + 1
                end

                if (open[neighbourKey] == nil or tentativePastCost < pastCost[neighbourKey]) then
                    pastCost[neighbourKey] = tentativePastCost

                    local neighbourFutureCost = heuristic(neighbour, goal)

                    if (neighbour.x ~= goal.x) then neighbourFutureCost = neighbourFutureCost + 1 end
                    if (neighbour.z ~= goal.z) then neighbourFutureCost = neighbourFutureCost + 1 end
                    if (neighbour.y ~= goal.y) then neighbourFutureCost = neighbourFutureCost + 1 end

                    futureCost[neighbourKey] = neighbourFutureCost
                    totalCost[neighbourKey] = pastCost[neighbourKey] + neighbourFutureCost

                    map[neighbourKey] = current

                    if (open[neighbourKey] == nil) then
                        open[neighbourKey] = neighbour
                        neighbours[i] = neighbour
                        numOpen = numOpen + 1
                    end
                end
            end
        end

        -- pruning
        if (map[currentKey] ~= nil) then
            for neighbourOrientation, neighbour in pairs(neighbours) do
                local neighbourKey = neighbour:tostring()

                if (neighbourOrientation == orientation) then
                    -- add natural neighbour
                    naturals[neighbourKey] = neighbour
                else
                    -- check blockade
                    local check = map[currentKey] + ORIENTATIONS.Deltas[neighbourOrientation] - ORIENTATIONS.Deltas[orientation]
                    local checkKey = check:tostring()

                    if (world[checkKey] == nil) then
                        -- add neighbour to prune
                        pruned[neighbourKey] = neighbour
                    else
                        -- add neighbour to forced
                        forced[neighbourKey] = neighbour
                    end
                end
            end
        end

        --        local progress = math.ceil(math.abs((lowestFutureCost / highestFutureCost) -1) * 100)
        --        coroutine.yield(progress)
    end

    return nil
end

local world = {
    --    ["0,1,0"] = true,
    --    ["-1,0,0"] = true,
    --    ["0,0,1"] = true,
    --    ["0,0,-1"] = true,
    --    ["1,0,0"] = true
}

local start = new(0, 0, 0)
local goal = new(0, 0, 0)

local startTime = os.time()
local path = Pathing.aStarPruning(world, start, goal, NORTH)
local endTime = os.time()

local duration = endTime - startTime