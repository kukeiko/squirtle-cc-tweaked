local Vector = require "elements.vector"
local Cardinal = require "elements.cardinal"
local State = require "squirtle.state"
local getNative = require "squirtle.get-native"
local Basic = require "squirtle.basic"
local Advanced = require "squirtle.advanced"

---@class Complex : Advanced
local Complex = {}
setmetatable(Complex, {__index = Advanced})

---@param action string
---@param direction string
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

---@param direction? string
---@param steps? integer
---@return boolean, integer, string?
function Complex.tryWalk(direction, steps)
    direction = direction or "forward"
    local native = getNative("go", direction)
    steps = steps or 1

    if State.simulate then
        -- [note] "tryWalk()" doesn't simulate any steps because it is assumed that it is called only to move until an unbreakable block is hit,
        -- and since we're not simulating an actual world we can not really return a meaningful value of steps taken.
        return false, 0
    end

    if not Basic.hasFuel(steps) then
        Advanced.refuelTo(steps)
    end

    local delta = Cardinal.toVector(Cardinal.fromSide(direction, State.facing))

    for step = 1, steps do
        local success, message = native()

        if success then
            State.position = Vector.plus(State.position, delta)
        else
            return false, step - 1, message
        end
    end

    return true, steps
end

---@param direction? string
---@param steps? integer
function Complex.walk(direction, steps)
    direction = direction or "forward"
    steps = steps or 1
    local success, stepsTaken, message = Complex.tryWalk(direction, steps)

    if success then
        return nil
    end

    error(getGoErrorMessage("walk", direction, steps, stepsTaken, message))
end

-- [todo] moving back still seems buggy if blocks are in the way
---@param direction? string
---@param steps? integer
---@return boolean, integer, string?
function Complex.tryMove(direction, steps)
    direction = direction or "forward"
    steps = steps or 1

    if State.simulate then
        State.results.steps = State.results.steps + 1
        return true, steps
    end

    local remainingSteps = steps
    local isBack = direction == "back"

    while true do
        local success, stepsTaken = Complex.tryWalk(direction, remainingSteps)

        if success then
            if isBack and remainingSteps ~= steps then
                Basic.turn("back")
            end

            return true, steps
        elseif isBack and direction ~= "forward" then
            Basic.turn("back")
            direction = "forward"
        end

        remainingSteps = remainingSteps - stepsTaken

        while Basic.tryMine(direction) do
        end

        local block = Basic.probe(direction)

        if block then
            if isBack then
                Basic.turn("back")
            end

            return false, steps - remainingSteps, string.format("blocked by %s", block.name)
        end
    end
end

---@param direction? string
---@param steps? integer
function Complex.move(direction, steps)
    direction = direction or "forward"
    steps = steps or 1
    local success, stepsTaken, message = Complex.tryMove(direction, steps)

    if success then
        return nil
    end

    error(getGoErrorMessage("move", direction, steps, stepsTaken, message))
end

---@param refresh? boolean
function Complex.locate(refresh)
    if refresh then
        local x, y, z = gps.locate()

        if not x then
            error("no gps available")
        end

        State.position = Vector.create(x, y, z)
    end

    return State.position
end

---@param position Vector
local function stepOut(position)
    Advanced.refuelTo(2)

    if not Complex.tryWalk("forward") then
        return false
    end

    local now = Complex.locate(true)
    State.facing = Cardinal.fromVector(Vector.minus(now, position))

    while not Complex.tryWalk("back") do
        print("can't move back, something is blocking me. sleeping 1s...")
        os.sleep(1)
    end

    return true
end

---@param position Vector
---@return boolean
local function orientateSameLayer(position)
    if stepOut(position) then
        return true
    end

    Basic.turn("left")

    if stepOut(position) then
        Basic.turn("right")
        return true
    end

    Basic.turn("left")

    if stepOut(position) then
        Basic.turn("back")
        return true
    end

    Basic.turn("left")

    if stepOut(position) then
        Basic.turn("left")
        return true
    end

    return false
end

---@param refresh? boolean
---@return Vector position, integer facing
function Complex.orientate(refresh)
    local position = Complex.locate(refresh)
    local facing = State.facing

    if refresh or not facing then
        if not orientateSameLayer(position) then
            error("failed to orientate. possibly blocked in.")
        end
    end

    return State.position, State.facing
end

return Complex
