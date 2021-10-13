local Squirtle = { }

--- <summary>
--- </summary>
--- <returns type="System.Squirtle"></returns>
function Squirtle.new()
    if (not turtle) then error("Not a turtle") end

    local instance = System.Computer.new()
    setmetatable(Squirtle, { __index = System.Computer })
    setmetatable(instance, { __index = Squirtle })
    instance:ctor()

    return instance
end

function Squirtle:ctor()
    self._em = EventManager.new()
end

function Squirtle:turn(side)
    local fnName

    if (side == LEFT) then
        fnName = "turnLeft"
    elseif (side == RIGHT) then
        fnName = "turnRight"
    else
        error("Squirtle:turn(): invalid arg, expected LEFT / RIGHT")
    end

    return self:call(fnName)
end

function Squirtle:move(side)
    local fnName

    if (side == FRONT) then
        fnName = "forward"
    elseif (side == TOP) then
        fnName = "up"
    elseif (side == BOTTOM) then
        fnName = "down"
    elseif (side == BACK) then
        fnName = "back"
    else
        error("Squirtle:move(): invalid arg, expected FRONT, TOP, BOTTOM, BACK")
    end

    return self:call(fnName)
end

function Squirtle:equip(side)
    local fnName

    if (side == LEFT) then
        fnName = "equipLeft"
    elseif (side == RIGHT) then
        fnName = "equipRight"
    else
        error("Squirtle:equip(): invalid arg, expected LEFT / RIGHT")
    end

    return self:call(fnName)
end

function Squirtle:attack(direction)
    direction = direction or FRONT

    local fnName

    if (direction == FRONT) then
        fnName = "attack"
    elseif (direction == UP) then
        fnName = "attackUp"
    elseif (direction == DOWN) then
        fnName = "attackDown"
    else
        error("Squirtle:attack(): invalid arg, expected FRONT, UP, DOWN")
    end

    return self:call(fnName)
end

function Squirtle:detect(direction)
    direction = direction or FRONT
    
    local fnName

    if (direction == FRONT) then
        fnName = "detect"
    elseif (direction == UP) then
        fnName = "detectUp"
    elseif (direction == DOWN) then
        fnName = "detectDown"
    else
        error("Squirtle:detect(): invalid arg, expected FRONT, UP, DOWN")
    end

    return self:call(fnName)
end

function Squirtle:place(direction)
    direction = direction or FRONT
    
    local fnName

    if (direction == FRONT) then
        fnName = "place"
    elseif (direction == UP) then
        fnName = "placeUp"
    elseif (direction == DOWN) then
        fnName = "placeDown"
    else
        error("Squirtle:place(): invalid arg, expected FRONT, UP, DOWN")
    end

    return self:call(fnName)
end

function Squirtle:drop(direction)
    direction = direction or FRONT
    
    local fnName

    if (direction == FRONT) then
        fnName = "drop"
    elseif (direction == UP) then
        fnName = "dropUp"
    elseif (direction == DOWN) then
        fnName = "dropDown"
    else
        error("Squirtle:drop(): invalid arg, expected FRONT, UP, DOWN")
    end

    return self:call(fnName)
end

function Squirtle:inspect(direction)
    direction = direction or FRONT
    
    local fnName

    if (direction == FRONT) then
        fnName = "inspect"
    elseif (direction == UP) then
        fnName = "inspectUp"
    elseif (direction == DOWN) then
        fnName = "inspectDown"
    else
        error("Squirtle:inspect(): invalid arg, expected FRONT, UP, DOWN")
    end

    return self:call(fnName)
end

function Squirtle:dig(direction)
    direction = direction or FRONT

    local fnName

    if (direction == FRONT) then
        fnName = "dig"
    elseif (direction == UP) then
        fnName = "digUp"
    elseif (direction == DOWN) then
        fnName = "digDown"
    else
        error("Squirtle:dig(): invalid arg, expected FRONT, UP, DOWN")
    end

    return self:call(fnName)
end

function Squirtle:call(funcName)
    local success, e = turtle[funcName]()
    if (success) then self._em:raise(funcName) end

    return success, e
end

function Squirtle:on(funcName, handler)
    return self._em:on(funcName, handler)
end

--- <summary>instance: (Squirtle)</summary>
--- <returns type="System.Squirtle"></returns>
function Squirtle.cast(instance)
    return instance
end

--- <summary>
--- Helper for BabeLua autocomplete
--- </summary>
--- <returns type="System.Computer"></returns>
function Squirtle:base()
    return self
end

function Squirtle:foo()
    return "Squirtle"
end

if (System == nil) then System = { } end
System.Squirtle = Squirtle