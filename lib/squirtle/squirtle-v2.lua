local selectItem = require "squirtle.backpack.select-item"
local turn = require "squirtle.turn"
local place = require "squirtle.place"
local dig = require "squirtle.dig"
local Vector = require "elements.vector"
local Cardinal = require "elements.cardinal"
local Fuel = require "squirtle.fuel"
local refuel = require "squirtle.refuel"
local inspect = require "squirtle.inspect"
local requireItems = require "squirtle.require-items"

---@class SquirtleV2SimulationResults
---@field steps integer
---@field placed table<string, integer>

local natives = {
    move = {
        top = turtle.up,
        up = turtle.up,
        front = turtle.forward,
        forward = turtle.forward,
        bottom = turtle.down,
        down = turtle.down,
        back = turtle.back
    }
}

---@param block Block
---@return boolean
local breakableSafeguard = function(block)
    return block.name ~= "minecraft:bedrock"
end

---@class SquirtleV2
---@field results SquirtleV2SimulationResults
---@field breakable? fun(block: Block) : boolean
local SquirtleV2 = {
    flipTurns = false,
    simulate = false,
    results = {placed = {}, steps = 0},
    position = Vector.create(0, 0, 0),
    facing = Cardinal.south
}

---@param predicate? fun(block: Block) : boolean
function SquirtleV2.enableBlockBreaking(predicate)
    SquirtleV2.breakable = predicate
end

function SquirtleV2.disableBlockBreaking()
    local current = SquirtleV2.breakable
    SquirtleV2.breakable = nil
    return current
end

---@param side? string
---@param steps? integer
---@return boolean, integer, string?
function SquirtleV2.tryMove(side, steps)
    side = side or "front"
    local handler = natives.move[side]

    if not handler then
        error(string.format("move() does not support side %s", side))
    end

    if SquirtleV2.simulate then
        if steps then
            SquirtleV2.results.steps = SquirtleV2.results.steps + 1
        else
            -- "tryMove()" doesn't simulate any steps because it is assumed that it is called only to move until an unbreakable block is hit,
            -- and since we're not simulating a world we can not really return a meaningful value of steps taken if none have been supplied.
            return false, 0, "simulation mode is active"
        end
    end

    steps = steps or 1

    if not Fuel.hasFuel(steps) then
        refuel(steps)
    end

    local delta = Cardinal.toVector(Cardinal.fromSide(side, SquirtleV2.facing))

    for step = 1, steps do
        repeat
            local success, error = handler()

            if not success then                    
                -- [todo] inspect error message (i.e. missing tool => error)
                local block = inspect(side)

                if not block then
                    -- [todo] it is possible (albeit unlikely) that between handler() and inspect(), a previously
                    -- existing block has been removed by someone else
                    error(string.format("move(%s) failed, but there is no block in the way", side))
                end

                if SquirtleV2.breakable and (breakableSafeguard(block) and SquirtleV2.breakable(block)) then
                    dig(side)
                else
                    return false, step - 1, string.format("undiggabble block '%s'", block.name)
                end
            end
        until success

        SquirtleV2.position = Vector.plus(SquirtleV2.position, delta)
    end

    return true, steps
end

---@param times? integer
---@return boolean, integer, string?
function SquirtleV2.tryForward(times)
    return SquirtleV2.tryMove("forward", times)
end

---@param times? integer
---@return boolean, integer, string?
function SquirtleV2.tryUp(times)
    return SquirtleV2.tryMove("up", times)
end

---@param times? integer
---@return boolean, integer, string?
function SquirtleV2.tryDown(times)
    return SquirtleV2.tryMove("down", times)
end

---@param times? integer
---@return boolean, integer, string?
function SquirtleV2.tryBack(times)
    return SquirtleV2.tryMove("back", times)
end

---@param side? string
---@param times? integer
function SquirtleV2.move(side, times)
    if SquirtleV2.simulate then
        -- when simulating, only "move()" will simulate actual steps.
        times = times or 1
        SquirtleV2.results.steps = SquirtleV2.results.steps + 1

        return nil
    end

    local success, _, message = SquirtleV2.tryMove(side, times)

    if not success then
        error(string.format("move(%s) failed: %s", side, message))
    end
end

---@param times? integer
function SquirtleV2.forward(times)
    SquirtleV2.move("forward", times)
end

---@param times? integer
function SquirtleV2.up(times)
    SquirtleV2.move("up", times)
end

---@param times? integer
function SquirtleV2.down(times)
    SquirtleV2.move("down", times)
end

---@param times? integer
function SquirtleV2.back(times)
    SquirtleV2.move("back", times)
end

---@param side? string
function SquirtleV2.turn(side)
    if not SquirtleV2.simulate then
        if SquirtleV2.flipTurns then
            if side == "left" then
                side = "right"
            elseif side == "right" then
                side = "left"
            end
        end

        turn(side)
    end
end

function SquirtleV2.left()
    SquirtleV2.turn("left")
end

function SquirtleV2.right()
    SquirtleV2.turn("right")
end

function SquirtleV2.around()
    SquirtleV2.turn("back")
end

---@param side? string
---@param toolSide? string
function SquirtleV2.dig(side, toolSide)
    if not SquirtleV2.simulate then
        dig(side, toolSide)
    end
end

---@param block string
---@param side? string
function SquirtleV2.place(block, side)
    if SquirtleV2.simulate then
        if not SquirtleV2.results.placed[block] then
            SquirtleV2.results.placed[block] = 0
        end

        SquirtleV2.results.placed[block] = SquirtleV2.results.placed[block] + 1
    else
        if not SquirtleV2.select(block, true) then
            requireItems({[block] = 1})

            if not SquirtleV2.select(block, true) then
                error("unexpected error")
            end
        end

        place(side)
    end
end

---@param block string
function SquirtleV2.placeUp(block)
    SquirtleV2.place(block, "up")
end

---@param block string
function SquirtleV2.placeDown(block)
    SquirtleV2.place(block, "down")
end

---@param name string
---@param exact? boolean
---@return false|integer
function SquirtleV2.select(name, exact)
    return selectItem(name, exact)
end

return SquirtleV2
