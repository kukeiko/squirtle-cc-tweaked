local Utils = require "utils"
local Cardinal = require "elements.cardinal"
local State = require "squirtle.state"
local getNative = require "squirtle.get-native"

---@class Elemental
local Elemental = {}

---@param direction string
function Elemental.turn(direction)
    if direction == "back" then
        Elemental.turn("left")
        Elemental.turn("left")
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
function Elemental.probe(direction, name)
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
    elseif type(name) == "table" and Utils.indexOf(name, block.name) > 0 then
        return block
    end
end

---@param direction? string
---@param text? string
---@return boolean, string?
function Elemental.place(direction, text)
    if State.simulate then
        return true
    end

    direction = direction or "front"
    return getNative("place", direction)(text)
end

---@return string? direction
function Elemental.placeFrontTopOrBottom()
    local directions = {"front", "top", "bottom"}

    for _, direction in pairs(directions) do
        if Elemental.place(direction) then
            return direction
        end
    end
end

---@param direction? string
---@param count? integer
---@return boolean, string?
function Elemental.drop(direction, count)
    if State.simulate then
        return true
    end

    direction = direction or "forward"
    return getNative("drop", direction)(count)
end

---@param direction? string
---@param count? integer
---@return boolean, string?
function Elemental.suck(direction, count)
    if State.simulate then
        return true
    end

    direction = direction or "forward"
    return getNative("suck", direction)(count)
end

---@param direction? string
---@param tool? string
---@return boolean, string?
function Elemental.dig(direction, tool)
    if State.simulate then
        return true
    end

    direction = direction or "forward"
    return getNative("dig", direction)(tool)
end

---@return integer|"unlimited"
function Elemental.getFuelLevel()
    return turtle.getFuelLevel()
end

---@return integer
function Elemental.getNonInfiniteFuelLevel()
    local fuel = Elemental.getFuelLevel()

    if type(fuel) ~= "number" then
        error("expected to not use unlimited fuel configuration")
    end

    return fuel
end

---@return integer|"unlimited"
function Elemental.getFuelLimit()
    return turtle.getFuelLimit()
end

---@param quantity? integer
---@return boolean, string?
function Elemental.refuel(quantity)
    return turtle.refuel(quantity)
end

---@return integer
function Elemental.size()
    return 16
end

---@param slot? integer
---@return integer
function Elemental.getItemCount(slot)
    return turtle.getItemCount(slot)
end

---@param slot? integer
---@return integer
function Elemental.getItemSpace(slot)
    return turtle.getItemSpace(slot)
end

---@param slot integer
---@return boolean
function Elemental.select(slot)
    if State.simulate then
        return true
    end

    return turtle.select(slot)
end

---@return integer
function Elemental.getSelectedSlot()
    return turtle.getSelectedSlot()
end

---@param slot integer
---@param detailed? boolean
---@return ItemStack?
function Elemental.getStack(slot, detailed)
    return turtle.getItemDetail(slot, detailed)
end

---@param slot integer
---@param quantity? integer
---@return boolean
function Elemental.transferTo(slot, quantity)
    return turtle.transferTo(slot, quantity)
end

return Elemental
