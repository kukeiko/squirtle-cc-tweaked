local Movement = { }

--- <summary>
--- </summary>
--- <returns type="Components.Squirtle.Movement"></returns>
function Movement.new(squirtle)
    local instance = Components.Squirtle.Component.new(squirtle, "Squirtle.Movement", { "Squirtle.Pickaxe", "Squirtle.Fueling", "Location" })

    setmetatable(Movement, { __index = Components.Squirtle.Component })
    setmetatable(instance, { __index = Movement })

    instance:ctor()

    return instance
end

function Movement:ctor()

end

--- <summary></summary>
--- <returns type="Components.Squirtle.Pickaxe"></returns>
function Movement:getPickaxe()
    return self:base():getDependency("Squirtle.Pickaxe")
end

--- <summary></summary>
--- <returns type="Components.Squirtle.Fueling"></returns>
function Movement:getFueling()
    return self:base():getDependency("Squirtle.Fueling")
end

--- <summary></summary>
--- <returns type="Components.Location"></returns>
function Movement:getLocation()
    return self:base():getDependency("Location")
end

--- <summary>instance: (Movement)</summary>
--- <returns type="Components.Squirtle.Movement"></returns>
function Movement.cast(instance)
    return instance
end

--- <summary>Helper for BabeLua autocomplete</summary>
--- <returns type="Components.Squirtle.Component"></returns>
function Movement:base()
    return self
end

--- <summary>Helper to call base class functions</summary>
--- <returns type="Components.Squirtle.Component"></returns>
function Movement.super()
    return Components.Squirtle.Component
end

function Movement:load()
    Movement.super().load(self)
end

function Movement:movePeaceful(side, times)
    local success, stepsMoved, e = self:tryMovePeaceful(side, times)

    if (not success) then
        error(e)
    end

    return stepsMoved
end

function Movement:tryMovePeaceful(side, times)
    self:getFueling():refuel(times)

    for i = 1, times do
        local success, e = self:base():getSquirtle():move(side)
        if (not success) then return false, i - 1, e end
    end

    return true, times
end

function Movement:moveAggressive(side, times)
    times = times or 1

    self:getFueling():refuel(times)
    local pickaxe = self:getPickaxe()
    local squirtle = self:base():getSquirtle()
    local success

    for i = 1, times do
        while (not success) do
            success, e = self:base():getSquirtle():move(side)

            if (not success) then
                if (squirtle:detect(side)) then
                    pickaxe:dig(side)
                else
                    pickaxe:attack()
                end
            end
        end

        success = false
    end
end

function Movement:moveToAggressive(point)
    local loc = self:getLocation():getLocation()
    local delta = point - loc

    if (delta.y > 0) then
        self:moveAggressive(UP, delta.y)
    elseif (delta.y < 0) then
        self:moveAggressive(DOWN, delta.y * -1)
    end

    if (delta.x > 0) then
        self:turnToOrientation(EAST)
        self:moveAggressive(FRONT, delta.x)
    elseif (delta.x < 0) then
        self:turnToOrientation(WEST)
        self:moveAggressive(FRONT, delta.x * -1)
    end

    if (delta.z > 0) then
        self:turnToOrientation(SOUTH)
        self:moveAggressive(FRONT, delta.z)
    elseif (delta.z < 0) then
        self:turnToOrientation(NORTH)
        self:moveAggressive(FRONT, delta.z * -1)
    end
end

function Movement:walkPathAggressive(path)
    local moved = false

    local loc = self:getLocation()
    self:getFueling():refuel(#path)

    for k, v in ipairs(path) do
        local delta = v - loc:getLocation()

        if (delta.x > 0) then
            self:turnToOrientation(EAST)
            self:moveAggressive(FRONT, delta.x)
        elseif (delta.x < 0) then
            self:turnToOrientation(WEST)
            self:moveAggressive(FRONT, delta.x * -1)
        elseif (delta.y > 0) then
            self:moveAggressive(UP, delta.y)
        elseif (delta.y < 0) then
            self:moveAggressive(DOWN, delta.y * -1)
        elseif (delta.z > 0) then
            self:turnToOrientation(SOUTH)
            self:moveAggressive(FRONT, delta.z)
        elseif (delta.z < 0) then
            self:turnToOrientation(NORTH)
            self:moveAggressive(FRONT, delta.z * -1)
        end
    end

    return true
end

function Movement:turn(side, times)
    times = times or 1

    for i = 1, times do
        self:base():getSquirtle():turn(side)
    end
end

function Movement:turnToOrientation(orientation)
    if (orientation == UP or orientation == BOTTOM) then return false end

    local currentOrientation = self:getLocation():getOrientation()
    local rightTurns =(orientation + 4 - currentOrientation) % 4
    local leftTurns = math.abs(orientation - 4 - currentOrientation) % 4

    if (leftTurns < rightTurns) then
        self:turn(LEFT, leftTurns)
    else
        self:turn(RIGHT, rightTurns)
    end
end

if (Components == nil) then Components = { } end
if (Components.Squirtle == nil) then Components.Squirtle = { } end
Components.Squirtle.Movement = Movement