local Cardinal = require "lib.models.cardinal"
local Vector = require "lib.models.vector"
local World = require "lib.models.world"
local getNative = require "lib.apis.turtle.functions.get-native"
local findPath = require "lib.apis.turtle.functions.find-path"
local TurtleStateApi = require "lib.apis.turtle.api-parts.turtle-state-api"

---@class TurtleMovementApi
local TurtleMovementApi = {}

---@param action string
---@param direction MoveDirection
---@param steps integer
---@param stepsTaken integer
---@param originalMessage? string
---@return string
local function getGoErrorMessage(action, direction, steps, stepsTaken, originalMessage)
    originalMessage = originalMessage or "(unknown error)"

    if steps == 1 then
        return string.format("failed to %s once towards %s: %s", action, direction, originalMessage)
    else
        return string.format("failed to %s %d steps (%d steps taken) towards %s: %s", action, steps, stepsTaken, direction, originalMessage)
    end
end

---@param direction MoveDirection
local function changePosition(direction)
    if TurtleStateApi.isSimulating() then
        error("can't change position: simulation active")
    end

    local delta = Cardinal.toVector(Cardinal.fromSide(direction, TurtleStateApi.getState().facing))
    TurtleStateApi.getState().position = Vector.plus(TurtleStateApi.getState().position, delta)
end

---@param direction string
local function simulateMove(direction)
    if not TurtleStateApi.isSimulating() then
        error("can't simulate move: not simulating")
    end

    local delta = Cardinal.toVector(Cardinal.fromSide(direction, TurtleStateApi.getFacing()))
    TurtleStateApi.getState().simulated.fuel = TurtleStateApi.getState().simulated.fuel - 1
    TurtleStateApi.getState().simulated.position = Vector.plus(TurtleStateApi.getState().simulated.position, delta)
    TurtleStateApi.checkResumeEnd()
end

---@param direction string
local function simulateTurn(direction)
    if not TurtleStateApi.isSimulating() then
        error("can't simulate turn: not simulating")
    end

    TurtleStateApi.getState().simulated.facing = Cardinal.rotate(TurtleStateApi.getState().simulated.facing, direction)
    TurtleStateApi.checkResumeEnd()
end

---@param TurtleApi TurtleApi
---@param steps integer?
---@return boolean, integer, string?
local function tryMoveBack(TurtleApi, steps)
    steps = steps or 1
    local native = getNative("go", "back")
    local didTurnBack = false
    local direction = "back"

    for step = 1, steps do
        if TurtleStateApi.isResuming() and TurtleStateApi.fuelTargetReached() and not TurtleStateApi.facingTargetReached() then
            -- we seem to be in correct position but the facing is off, meaning that there must've been
            -- a block that caused us to turn to try and mine it. in order to resume, we'll just
            -- stop the simulation and orient the turtle so that the turning code gets run from the beginning.
            local facing = TurtleStateApi.getFacing()
            TurtleStateApi.endResume()
            TurtleMovementApi.face(facing)
        end

        if TurtleStateApi.isSimulating() then
            simulateMove("back")
        else
            while not native() do
                if not didTurnBack then
                    TurtleMovementApi.turn("right")
                    TurtleMovementApi.turn("right")
                    native = getNative("go", "forward")
                    didTurnBack = true
                    direction = "forward"
                end

                while TurtleApi.tryMine() do
                end

                local block = TurtleApi.probe()

                if block and not TurtleStateApi.canBreak(block) then
                    TurtleMovementApi.turn("left")
                    TurtleMovementApi.turn("left")

                    return false, step - 1, string.format("blocked by %s", block.name)
                end
            end

            changePosition(direction)
        end
    end

    if didTurnBack then
        TurtleMovementApi.turn("left")
        TurtleMovementApi.turn("left")
    end

    return true, steps
end

---[todo] ❌ tryMove() should throw an error if called directly when simulating. since move() can be called while simulating,
---i'll need to move the function body out so move() can still call it.
---@param TurtleApi TurtleApi
---@param direction MoveDirection?
---@param steps integer?
---@return boolean, integer, string?
function TurtleMovementApi.tryMove(TurtleApi, direction, steps)
    steps = steps or 1

    if not TurtleStateApi.isSimulating() and not TurtleStateApi.hasFuel(steps) then
        TurtleApi.refuelTo(steps)
    end

    if direction == "back" then
        return tryMoveBack(TurtleApi, steps)
    end

    direction = direction or "forward"
    local native = getNative("go", direction)

    for step = 1, steps do
        if TurtleStateApi.isSimulating() then
            simulateMove(direction)
        else
            while not native() do
                while TurtleApi.tryMine(direction) do
                end

                local block = TurtleApi.probe(direction)

                if block and not TurtleStateApi.canBreak(block) then
                    return false, step - 1, string.format("blocked by %s", block.name)
                end
            end

            changePosition(direction)
        end
    end

    return true, steps
end

---@param TurtleApi TurtleApi
---@param direction? MoveDirection
---@param steps? integer
function TurtleMovementApi.move(TurtleApi, direction, steps)
    direction = direction or "forward"
    steps = steps or 1
    local success, stepsTaken, message = TurtleMovementApi.tryMove(TurtleApi, direction, steps)

    if success then
        return nil
    end

    error(getGoErrorMessage("move", direction, steps, stepsTaken, message))
end

---@param TurtleApi TurtleApi
---@param direction? MoveDirection
---@param steps? integer
---@return boolean success, integer stepsTaken, string? error
function TurtleMovementApi.tryWalk(TurtleApi, direction, steps)
    direction = direction or "forward"
    local native = getNative("go", direction)
    steps = steps or 1

    if TurtleStateApi.isSimulating() then
        -- [note] "tryWalk()" doesn't simulate any steps because it is assumed that it is called only to move until an unbreakable block is hit,
        -- and since we're not simulating an actual world we can not really return a meaningful value of steps taken.
        return false, 0
    end

    if not TurtleStateApi.hasFuel(steps) then
        TurtleApi.refuelTo(steps)
    end

    for step = 1, steps do
        local success, message = native()

        if success then
            changePosition(direction)
        else
            return false, step - 1, message
        end
    end

    return true, steps
end

---@param TurtleApi TurtleApi
---@param direction? MoveDirection
---@param steps? integer
function TurtleMovementApi.walk(TurtleApi, direction, steps)
    direction = direction or "forward"
    steps = steps or 1
    local success, stepsTaken, message = TurtleMovementApi.tryWalk(TurtleApi, direction, steps)

    if success then
        return nil
    end

    -- [todo] ❌ will always throw if simulation is active - is that intended?
    error(getGoErrorMessage("walk", direction, steps, stepsTaken, message))
end

---@param direction string
function TurtleMovementApi.turn(direction)
    if direction == "back" then
        TurtleMovementApi.turn("left")
        TurtleMovementApi.turn("left")
    elseif direction == "left" or direction == "right" then
        if TurtleStateApi.getFlipTurns() then
            if direction == "left" then
                direction = "right"
            elseif direction == "right" then
                direction = "left"
            end
        end

        if TurtleStateApi.isSimulating() then
            simulateTurn(direction)
        else
            getNative("turn", direction)()
            TurtleStateApi.changeFacing(direction)
        end
    end
end

---@param target integer
function TurtleMovementApi.face(target)
    local current = TurtleStateApi.getFacing()

    if (current + 2) % 4 == target then
        TurtleMovementApi.turn("back")
    elseif (current + 1) % 4 == target then
        TurtleMovementApi.turn("right")
    elseif (current - 1) % 4 == target then
        TurtleMovementApi.turn("left")
    end

    return target
end

---@param TurtleApi TurtleApi
---@param direction "left" | "right"
function TurtleMovementApi.strafe(TurtleApi, direction)
    TurtleMovementApi.turn(direction)
    TurtleMovementApi.move(TurtleApi)
    local inverse = direction == "left" and "right" or "left"
    TurtleMovementApi.turn(inverse)
end

---@param TurtleApi TurtleApi
---@param target Vector
---@return boolean, string?
function TurtleMovementApi.tryMoveToPoint(TurtleApi, target)
    local delta = Vector.minus(target, TurtleStateApi.getPosition())

    if delta.y > 0 then
        if not TurtleMovementApi.tryMove(TurtleApi, "up", delta.y) then
            return false, "top"
        end
    elseif delta.y < 0 then
        if not TurtleMovementApi.tryMove(TurtleApi, "down", -delta.y) then
            return false, "bottom"
        end
    end

    if delta.x > 0 then
        TurtleMovementApi.face(Cardinal.east)

        if not TurtleMovementApi.tryMove(TurtleApi, "forward", delta.x) then
            return false, "front"
        end
    elseif delta.x < 0 then
        TurtleMovementApi.face(Cardinal.west)

        if not TurtleMovementApi.tryMove(TurtleApi, "forward", -delta.x) then
            return false, "front"
        end
    end

    if delta.z > 0 then
        TurtleMovementApi.face(Cardinal.south)

        if not TurtleMovementApi.tryMove(TurtleApi, "forward", delta.z) then
            return false, "front"
        end
    elseif delta.z < 0 then
        TurtleMovementApi.face(Cardinal.north)

        if not TurtleMovementApi.tryMove(TurtleApi, "forward", -delta.z) then
            return false, "front"
        end
    end

    return true
end

---@param TurtleApi TurtleApi
---@---@param target Vector
function TurtleMovementApi.moveToPoint(TurtleApi, target)
    if not TurtleMovementApi.tryMoveToPoint(TurtleApi, target) then
        error(string.format("failed to move to %d/%d/%d", target.x, target.y, target.z))
    end
end

---@param TurtleApi TurtleApi
---@param path Vector[]
---@return boolean, string?, integer?
local function tryMovePath(TurtleApi, path)
    for i, next in ipairs(path) do
        local success, failedSide = TurtleMovementApi.tryMoveToPoint(TurtleApi, next)

        if not success then
            return false, failedSide, i
        end
    end

    return true
end

---@param TurtleApi TurtleApi
---@param to Vector
---@param world? World
---@param breakable? function
---@return boolean, string?
function TurtleMovementApi.navigate(TurtleApi, to, world, breakable)
    breakable = breakable or function()
        return false
    end

    local restoreBreakable = TurtleStateApi.setBreakable(breakable)

    if not world then
        local position = TurtleStateApi.getPosition()
        world = World.create(position.x, position.y, position.z)
    end

    local from = TurtleStateApi.getPosition()
    local facing = TurtleStateApi.getFacing()

    while true do
        local path, msg = findPath(from, to, facing, world)

        if not path then
            restoreBreakable()
            return false, msg
        end

        local distance = Vector.manhattan(from, to)
        TurtleApi.refuelTo(distance)
        local success, failedSide = tryMovePath(TurtleApi, path)

        if success then
            restoreBreakable()
            return true
        elseif failedSide then
            from = TurtleStateApi.getPosition()
            facing = TurtleStateApi.getFacing()
            local scannedLocation = Vector.plus(from, Cardinal.toVector(Cardinal.fromSide(failedSide, facing)))
            World.setBlock(world, scannedLocation)
        end
    end
end

---@param TurtleApi TurtleApi
---@param checkEarlyExit? fun() : boolean
---@return boolean
function TurtleMovementApi.navigateTunnel(TurtleApi, checkEarlyExit)
    local forbidden

    while true do
        local strategy

        if TurtleMovementApi.tryWalk(TurtleApi, "forward") then
            strategy = "forward"
            forbidden = "back"
        elseif forbidden ~= "up" and TurtleMovementApi.tryWalk(TurtleApi, "up") then
            strategy = "up"
            forbidden = "down"
        elseif forbidden ~= "down" and TurtleMovementApi.tryWalk(TurtleApi, "down") then
            strategy = "down"
            forbidden = "up"
        elseif TurtleMovementApi.turn("left") and TurtleMovementApi.tryWalk(TurtleApi, "forward") then
            strategy = "forward"
            forbidden = "back"
        elseif TurtleMovementApi.turn("left") and forbidden ~= "back" and TurtleMovementApi.tryWalk(TurtleApi, "forward") then
            strategy = "forward"
            forbidden = "back"
        elseif TurtleMovementApi.turn("left") and TurtleMovementApi.tryWalk(TurtleApi, "forward") then
            strategy = "forward"
            forbidden = "back"
        else
            return true
        end

        if strategy == "forward" then
            while TurtleMovementApi.tryWalk(TurtleApi, "forward") do
            end
        elseif strategy == "up" then
            while TurtleMovementApi.tryWalk(TurtleApi, "up") do
            end
        elseif strategy == "down" then
            while TurtleMovementApi.tryWalk(TurtleApi, "down") do
            end
        end

        if checkEarlyExit ~= nil and checkEarlyExit() then
            return checkEarlyExit()
        end
    end
end

return TurtleMovementApi
