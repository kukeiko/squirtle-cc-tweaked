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
---@field timesMoved integer
---@field blocksPlaced table<string, integer>

---@class SquirtleV2
---@field results SquirtleV2SimulationResults
---@field breakable fun(block: Block) : boolean
local SquirtleV2 = {
    flipTurns = false,
    simulate = false,
    results = {blocksPlaced = {}, timesMoved = 0},
    position = Vector.create(0, 0, 0),
    facing = Cardinal.south,
    breakable = function()
        return true
    end
}

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

---@param side? string
---@param times? integer
---@return boolean, Block?
function SquirtleV2.tryMove(side, times)
    side = side or "front"
    local handler = natives.move[side]

    if not handler then
        error(string.format("move() does not support side %s", side))
    end

    if SquirtleV2.simulate then
        return false
    end

    times = times or 1

    if not Fuel.hasFuel(times) then
        refuel(times)
    end

    local delta = Cardinal.toVector(Cardinal.fromSide(side, SquirtleV2.facing))

    for _ = 1, times do
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

                if block.name == "minecraft:bedrock" or not SquirtleV2.breakable(block) then
                    return false, block
                else
                    dig(side)
                end
            end
        until success

        SquirtleV2.position = Vector.plus(SquirtleV2.position, delta)
    end

    return true
end

---@param times? integer
---@return boolean, Block?
function SquirtleV2.tryForward(times)
    return SquirtleV2.tryMove("forward", times)
end

---@param times? integer
---@return boolean, Block?
function SquirtleV2.tryUp(times)
    return SquirtleV2.tryMove("up", times)
end

---@param times? integer
---@return boolean, Block?
function SquirtleV2.tryDown(times)
    return SquirtleV2.tryMove("down", times)
end

---@param times? integer
---@return boolean, Block?
function SquirtleV2.tryBack(times)
    return SquirtleV2.tryMove("back", times)
end

---@param side? string
---@param times? integer
function SquirtleV2.move(side, times)
    if SquirtleV2.simulate then
        times = times or 1
        SquirtleV2.results.timesMoved = SquirtleV2.results.timesMoved + 1

        return nil
    end

    local success, block = SquirtleV2.tryMove(side, times)

    if not success then
        if block then
            error(string.format("move(%s) failed: undiggabble block '%s'", side, block.name))
        else
            error(string.format("move(%s) failed, but there is no block in the way", side))
        end
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
        if not SquirtleV2.results.blocksPlaced[block] then
            SquirtleV2.results.blocksPlaced[block] = 0
        end

        SquirtleV2.results.blocksPlaced[block] = SquirtleV2.results.blocksPlaced[block] + 1
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
