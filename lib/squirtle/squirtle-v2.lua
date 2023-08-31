local selectItem = require "squirtle.backpack.select-item"
local findItem = require "squirtle.backpack.find"
local turn = require "squirtle.turn"
local place = require "squirtle.place"
local Vector = require "elements.vector"
local Cardinal = require "elements.cardinal"
local Fuel = require "squirtle.fuel"
local refuel = require "squirtle.refuel"
local requireItems = require "squirtle.require-items"
local Utils = require "utils"
local Backpack = require "squirtle.backpack"

---@class SquirtleV2SimulationResults
---@field steps integer
---@field placed table<string, integer>

local inventorySize = 16

local natives = {
    move = {
        top = turtle.up,
        up = turtle.up,
        front = turtle.forward,
        forward = turtle.forward,
        bottom = turtle.down,
        down = turtle.down,
        back = turtle.back
    },
    dig = {
        top = turtle.digUp,
        up = turtle.digUp,
        front = turtle.dig,
        forward = turtle.dig,
        bottom = turtle.digDown,
        down = turtle.digDown
    },
    inspect = {
        top = turtle.inspectUp,
        up = turtle.inspectUp,
        front = turtle.inspect,
        forward = turtle.inspect,
        bottom = turtle.inspectDown,
        down = turtle.inspectDown
    },
    suck = {
        top = turtle.suckUp,
        up = turtle.suckUp,
        front = turtle.suck,
        forward = turtle.suck,
        bottom = turtle.suckDown,
        down = turtle.suckDown
    }
}

---@param block Block
---@return boolean
local breakableSafeguard = function(block)
    return block.name ~= "minecraft:bedrock"
end

---@class SquirtleV2
---@field flipTurns boolean
---@field simulate boolean
---@field facing integer
---@field results SquirtleV2SimulationResults
---@field breakable? fun(block: Block) : boolean
local SquirtleV2 = {
    flipTurns = false,
    simulate = false,
    results = {placed = {}, steps = 0},
    position = Vector.create(0, 0, 0),
    facing = Cardinal.south
}

---@param block Block
---@return boolean
local function canBreak(block)
    return SquirtleV2.breakable ~= nil and breakableSafeguard(block) and SquirtleV2.breakable(block)
end

---@param predicate? (fun(block: Block) : boolean) | string[]
---@return fun() : nil
function SquirtleV2.setBreakable(predicate)
    local current = SquirtleV2.breakable

    local function restore()
        SquirtleV2.breakable = current
    end

    if type(predicate) == "table" then
        SquirtleV2.breakable = function(block)
            for _, item in pairs(predicate) do
                if block.name == item then
                    return true
                end
            end

            return false
        end
    else
        SquirtleV2.breakable = predicate
    end

    return restore
end

---@param side? string
---@param steps? integer
---@return boolean, integer, string?
function SquirtleV2.tryMove(side, steps)
    side = side or "front"
    local native = natives.move[side]

    if not native then
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
            local success, error = native()

            if not success then
                local actionSide = side

                if side == "back" then
                    actionSide = "front"
                    SquirtleV2.around()
                end

                local block = SquirtleV2.inspect(actionSide)

                if not block then
                    if side == "back" then
                        SquirtleV2.around()
                    end

                    -- [todo] it is possible (albeit unlikely) that between handler() and inspect(), a previously
                    -- existing block has been removed by someone else
                    error(string.format("move(%s) failed, but there is no block in the way", side))
                end

                -- [todo] wanted to reuse newly introduced Squirtle.tryDig(), but it would be awkward to do so.
                -- maybe I find a non-awkward solution in the future?
                -- [todo] should tryDig really try to dig? I think I am going to use this only for "move until you hit something",
                -- so in that case, no, it shouldn't try to dig.
                if canBreak(block) then
                    while SquirtleV2.dig(actionSide) do
                    end

                    if side == "back" then
                        SquirtleV2.around()
                    end
                else
                    if side == "back" then
                        SquirtleV2.around()
                    end

                    return false, step - 1, string.format("blocked by %s", block.name)
                end
            end
        until success

        SquirtleV2.position = Vector.plus(SquirtleV2.position, delta)
    end

    return true, steps
end

---@param steps? integer
---@return boolean, integer, string?
function SquirtleV2.tryForward(steps)
    return SquirtleV2.tryMove("forward", steps)
end

---@param steps? integer
---@return boolean, integer, string?
function SquirtleV2.tryUp(steps)
    return SquirtleV2.tryMove("up", steps)
end

---@param steps? integer
---@return boolean, integer, string?
function SquirtleV2.tryDown(steps)
    return SquirtleV2.tryMove("down", steps)
end

---@param steps? integer
---@return boolean, integer, string?
function SquirtleV2.tryBack(steps)
    return SquirtleV2.tryMove("back", steps)
end

---@param side? string
---@param steps? integer
function SquirtleV2.move(side, steps)
    if SquirtleV2.simulate then
        -- when simulating, only "move()" will simulate actual steps.
        steps = steps or 1
        SquirtleV2.results.steps = SquirtleV2.results.steps + 1

        return nil
    end

    local success, _, message = SquirtleV2.tryMove(side, steps)

    if not success then
        error(string.format("move(%s) failed: %s", side, message))
    end
end

---@param steps? integer
function SquirtleV2.forward(steps)
    SquirtleV2.move("forward", steps)
end

---@param steps? integer
function SquirtleV2.up(steps)
    SquirtleV2.move("up", steps)
end

---@param steps? integer
function SquirtleV2.down(steps)
    SquirtleV2.move("down", steps)
end

---@param steps? integer
function SquirtleV2.back(steps)
    SquirtleV2.move("back", steps)
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
---@return boolean, string?
function SquirtleV2.tryDig(side)
    if SquirtleV2.simulate then
        return true
    end

    side = side or "front"
    local native = natives.dig[side]

    if not native then
        error(string.format("dig() does not support side %s", side))
    end

    local block = SquirtleV2.inspect(side)

    if not block then
        return false
    end

    if not canBreak(block) then
        return false, string.format("not allowed to dig block %s", block.name)
    end

    local success, message = native()

    if not success and string.match(message, "tool") then
        error(string.format("dig(%s) failed: %s", side, message))
    end

    return success, message
end

---@param side? string
---@return boolean, string?
function SquirtleV2.dig(side)
    local success, message = SquirtleV2.tryDig(side)

    -- if there is no message, then there just wasn't anything to dig, meaning every other case is interpreted as an error
    if not success and message then
        error(message)
    end

    return success
end

---@return boolean, string?
function SquirtleV2.digUp()
    return SquirtleV2.dig("up")
end

---@return boolean, string?
function SquirtleV2.digDown()
    return SquirtleV2.dig("down")
end

---@param block? string
---@param requireItem? boolean
---@param side? string
function SquirtleV2.place(block, requireItem, side)
    requireItem = requireItem or true

    if SquirtleV2.simulate then
        if block then
            if not SquirtleV2.results.placed[block] then
                SquirtleV2.results.placed[block] = 0
            end

            SquirtleV2.results.placed[block] = SquirtleV2.results.placed[block] + 1
        end
    else
        if block and requireItem then
            while not SquirtleV2.select(block, true) do
                requireItems({[block] = 1})
            end
        end

        -- [todo] error handling
        place(side)
    end
end

---@param block? string
---@param requireItem? boolean
function SquirtleV2.placeUp(block, requireItem)
    SquirtleV2.place(block, requireItem, "up")
end

---@param block? string
---@param requireItem? boolean
function SquirtleV2.placeDown(block, requireItem)
    SquirtleV2.place(block, requireItem, "down")
end

---@param name string|integer
---@param exact? boolean
---@return false|integer
function SquirtleV2.select(name, exact)
    if type(name) == "string" then
        return selectItem(name, exact)
    else
        return turtle.select(name)
    end
end

---@param startAt? number
function SquirtleV2.selectEmpty(startAt)
    startAt = startAt or turtle.getSelectedSlot()

    for i = 0, inventorySize - 1 do
        local slot = startAt + i

        if slot > inventorySize then
            slot = slot - inventorySize
        end

        if turtle.getItemCount(slot) == 0 then
            return turtle.select(slot)
        end
    end

    return nil
end

---@param item string
---@param minCount? integer
---@return boolean
function SquirtleV2.has(item, minCount)
    if type(minCount) == "number" then
        return Backpack.getItemStock(item) >= minCount
    else
        return findItem(item, true) ~= nil
    end
end

---@return table<string, integer>
function SquirtleV2.getStock()
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(Backpack.getStacks()) do
        stock[stack.name] = (stock[stack.name] or 0) + stack.count
    end

    return stock
end

function SquirtleV2.condense()
    Backpack.condense()
end

---@param side? string
---@param name? table|string
---@return Block? block
function SquirtleV2.inspect(side, name)
    side = side or "front"
    local native = natives.inspect[side]

    if not native then
        error(string.format("inspect() does not support side %s", side))
    end

    local success, block = native()

    if success then
        if name then
            if type(name) == "string" and block.name == name then
                return block
            elseif type(name) == "table" and Utils.indexOf(name, block.name) > 0 then
                return block
            else
                return nil
            end
        end

        return block
    else
        return nil
    end
end

---@param side? string
---@param limit? integer
---@return boolean, string?
function SquirtleV2.suck(side, limit)
    side = side or "front"
    local native = natives.suck[side]

    if not native then
        error(string.format("suck() does not support side %s", side))
    end

    return native(limit)
end

return SquirtleV2
