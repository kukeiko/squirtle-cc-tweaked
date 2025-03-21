local Utils = require "lib.tools.utils"
local Vector = require "lib.models.vector"
local Cardinal = require "lib.models.cardinal"
local State = require "lib.squirtle.state"
local getNative = require "lib.squirtle.get-native"

---@class SquirtleElementalApi
local SquirtleElementalApi = {}

---@return integer
function SquirtleElementalApi.getFacing()
    if State.simulate then
        return State.simulation.current.facing
    end

    return State.facing
end

---@param facing integer
function SquirtleElementalApi.setFacing(facing)
    State.facing = facing
end

---@return Vector
function SquirtleElementalApi.getPosition()
    if State.simulate then
        return Vector.copy(State.simulation.current.position)
    end

    return Vector.copy(State.position)
end

---@param position Vector
function SquirtleElementalApi.setPosition(position)
    State.position = position
end

---@param delta Vector
function SquirtleElementalApi.changePosition(delta)
    State.position = Vector.plus(State.position, delta)
end

---@param direction string
function SquirtleElementalApi.turn(direction)
    if direction == "back" then
        SquirtleElementalApi.turn("left")
        SquirtleElementalApi.turn("left")
    elseif direction == "left" or direction == "right" then
        if State.flipTurns then
            if direction == "left" then
                direction = "right"
            elseif direction == "right" then
                direction = "left"
            end
        end

        if State.simulate then
            State.advanceTurn(direction)
        else
            getNative("turn", direction)()
            State.facing = Cardinal.rotate(State.facing, direction)
        end
    end
end

---@param direction? string
---@param name? table|string
---@return Block? block
function SquirtleElementalApi.probe(direction, name)
    direction = direction or "front"
    local success, block = getNative("inspect", direction)()

    if not success then
        return nil
    end

    if not name then
        return block
    end

    if type(name) == "string" and block.name == name then
        return block
    elseif type(name) == "table" and Utils.indexOf(name, block.name) then
        return block
    end
end

---@param direction? string
---@param text? string
---@return boolean, string?
function SquirtleElementalApi.place(direction, text)
    if State.simulate then
        return true
    end

    direction = direction or "front"
    return getNative("place", direction)(text)
end

---@param directions PlaceSide[]
---@return string? placedDirection
function SquirtleElementalApi.placeAtOneOf(directions)
    for i = 1, #directions do
        if SquirtleElementalApi.place(directions[i]) then
            return directions[i]
        end
    end
end

---@return string? direction
function SquirtleElementalApi.placeTopOrBottom()
    local directions = {"top", "bottom"}

    for _, direction in pairs(directions) do
        if SquirtleElementalApi.place(direction) then
            return direction
        end
    end
end

---@return string? direction
function SquirtleElementalApi.placeFrontTopOrBottom()
    local directions = {"front", "top", "bottom"}

    for _, direction in pairs(directions) do
        if SquirtleElementalApi.place(direction) then
            return direction
        end
    end
end

---@param direction? string
---@param count? integer
---@return boolean, string?
function SquirtleElementalApi.drop(direction, count)
    if State.simulate then
        return true
    end

    direction = direction or "forward"
    return getNative("drop", direction)(count)
end

---@param direction? string
---@param count? integer
---@return boolean, string?
function SquirtleElementalApi.suck(direction, count)
    if State.simulate then
        return true
    end

    direction = direction or "forward"
    return getNative("suck", direction)(count)
end

---@param direction? string
function SquirtleElementalApi.suckAll(direction)
    while SquirtleElementalApi.suck(direction) do
    end
end

---@param direction? string
---@param tool? string
---@return boolean, string?
function SquirtleElementalApi.dig(direction, tool)
    if State.simulate then
        return true
    end

    direction = direction or "forward"
    return getNative("dig", direction)(tool)
end

---@param directions DigSide[]
---@return string? dugDirection
function SquirtleElementalApi.digAtOneOf(directions)
    for i = 1, #directions do
        if SquirtleElementalApi.dig(directions[i]) then
            return directions[i]
        end
    end
end

---@return integer|"unlimited"
function SquirtleElementalApi.getFuelLevel()
    if State.simulate then
        return State.simulation.current.fuel
    end

    return turtle.getFuelLevel()
end

---@return integer
function SquirtleElementalApi.getNonInfiniteFuelLevel()
    local fuel = SquirtleElementalApi.getFuelLevel()

    if type(fuel) ~= "number" then
        error("expected to not use unlimited fuel configuration")
    end

    return fuel
end

---@return integer|"unlimited"
function SquirtleElementalApi.getFuelLimit()
    return turtle.getFuelLimit()
end

---@param quantity? integer
---@return boolean, string?
function SquirtleElementalApi.refuel(quantity)
    return turtle.refuel(quantity)
end

---@return integer
function SquirtleElementalApi.size()
    return 16
end

---@param slot? integer
---@return integer
function SquirtleElementalApi.getItemCount(slot)
    return turtle.getItemCount(slot)
end

---@param slot? integer
---@return integer
function SquirtleElementalApi.getItemSpace(slot)
    return turtle.getItemSpace(slot)
end

---@param slot integer
---@return boolean
function SquirtleElementalApi.select(slot)
    if State.simulate then
        return true
    end

    return turtle.select(slot)
end

---@return integer
function SquirtleElementalApi.getSelectedSlot()
    return turtle.getSelectedSlot()
end

---@param slot integer
---@param detailed? boolean
---@return ItemStack?
function SquirtleElementalApi.getStack(slot, detailed)
    return turtle.getItemDetail(slot, detailed)
end

---@param slot integer
---@param quantity? integer
---@return boolean
function SquirtleElementalApi.transferTo(slot, quantity)
    return turtle.transferTo(slot, quantity)
end

return SquirtleElementalApi
