local TurtleApi = { }

--- <summary>
--- </summary>
--- <returns type="Squirtle.TurtleApi"></returns>
function TurtleApi.new(turtle, equipment)
    local instance = { }
    setmetatable(instance, { __index = TurtleApi })
    instance:ctor(turtle, equipment)

    return instance
end

--- <summary>
--- </summary>
--- <returns type="Squirtle.TurtleApi"></returns>
function TurtleApi.as(instance)
    return instance
end

function TurtleApi:ctor(turtle, equipment)
    self._em = EventManager.new()
end

function TurtleApi:call(funcName)
    local success, e = turtle[funcName]()
    if (success) then self._em:raise(funcName) end

    return success, e
end

function TurtleApi:on(funcName, handler)
    return self._em:on(funcName, handler)
end

function TurtleApi:turn(side)
    local fnName

    if (side == LEFT) then
        fnName = "turnLeft"
    elseif (side == RIGHT) then
        fnName = "turnRight"
    else
        error("TurtleApi:turn(): invalid arg, expected LEFT / RIGHT")
    end

    return self:call(fnName)
end

function TurtleApi:move(side)
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
        error("TurtleApi:move(): invalid arg, expected FRONT, TOP, BOTTOM, BACK")
    end

    return self:call(fnName)
end

function TurtleApi:equip(side)
    local fnName

    if (side == LEFT) then
        fnName = "equipLeft"
    elseif (side == RIGHT) then
        fnName = "equipRight"
    else
        error("TurtleApi:equip(): invalid arg, expected LEFT / RIGHT")
    end

    return self:call(fnName)
end

function TurtleApi:attack(direction)
    direction = direction or FRONT

    local fnName

    if (direction == FRONT) then
        fnName = "attack"
    elseif (direction == UP) then
        fnName = "attackUp"
    elseif (direction == DOWN) then
        fnName = "attackDown"
    else
        error("TurtleApi:attack(): invalid arg, expected FRONT, UP, DOWN")
    end

    return self:call(fnName)
end

function TurtleApi:detect(direction)
    direction = direction or FRONT

    local fnName

    if (direction == FRONT) then
        fnName = "detect"
    elseif (direction == UP) then
        fnName = "detectUp"
    elseif (direction == DOWN) then
        fnName = "detectDown"
    else
        error("TurtleApi:detect(): invalid arg, expected FRONT, UP, DOWN")
    end

    return self:call(fnName)
end

function TurtleApi:place(direction)
    direction = direction or FRONT

    local fnName

    if (direction == FRONT) then
        fnName = "place"
    elseif (direction == UP) then
        fnName = "placeUp"
    elseif (direction == DOWN) then
        fnName = "placeDown"
    else
        error("TurtleApi:place(): invalid arg, expected FRONT, UP, DOWN")
    end

    return self:call(fnName)
end

function TurtleApi:drop(direction)
    direction = direction or FRONT

    local fnName

    if (direction == FRONT) then
        fnName = "drop"
    elseif (direction == UP) then
        fnName = "dropUp"
    elseif (direction == DOWN) then
        fnName = "dropDown"
    else
        error("TurtleApi:drop(): invalid arg, expected FRONT, UP, DOWN")
    end

    return self:call(fnName)
end

function TurtleApi:inspect(direction)
    direction = direction or FRONT

    local fnName

    if (direction == FRONT) then
        fnName = "inspect"
    elseif (direction == UP) then
        fnName = "inspectUp"
    elseif (direction == DOWN) then
        fnName = "inspectDown"
    else
        error("TurtleApi:inspect(): invalid arg, expected FRONT, UP, DOWN")
    end

    return self:call(fnName)
end

function TurtleApi:dig(direction)
    direction = direction or FRONT

    local fnName

    if (direction == FRONT) then
        fnName = "dig"
    elseif (direction == UP) then
        fnName = "digUp"
    elseif (direction == DOWN) then
        fnName = "digDown"
    else
        error("TurtleApi:dig(): invalid arg, expected FRONT, UP, DOWN")
    end

    return self:call(fnName)
end

function TurtleApi:getFuelLimit()
    return turtle.getFuelLimit()
end

function TurtleApi:getFuelLevel()
    return turtle.getFuelLevel()
end

function TurtleApi:refuel(num)
    return turtle.refuel(num)
end

function TurtleApi:getItemCount(slot)
    return turtle.getItemCount(slot)
end

function TurtleApi:getItemSpace(slot)
    return turtle.getItemSpace(slot)
end

function TurtleApi:getMissingQuantity(slot)
    return turtle.getMissingQuantity(slot)
end

function TurtleApi:getItemDetail(slot)
    return turtle.getItemDetail(slot)
end

function TurtleApi:select(slot)
    return turtle.select(slot)
end

function TurtleApi:transferTo(toSlot, quantity)
    return turtle.transferTo(toSlot, quantity)
end

if (Squirtle == nil) then Squirtle = { } end
Squirtle.TurtleApi = TurtleApi