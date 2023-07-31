local requireItems = require "squirtle.require-items"

---@class SimulatableSquirtle
---@field squirtle Squirtle
---@field simulate boolean
---@field timesMoved integer
---@field blocksPlaced table<string, integer>
local SimulatableSquirtle = {}

---@param squirtle Squirtle
---@return SimulatableSquirtle
function SimulatableSquirtle:new(squirtle)
    ---@type SimulatableSquirtle
    local instance = {squirtle = squirtle, simulate = false, timesMoved = 0, blocksPlaced = {}}

    return setmetatable(instance, {__index = self})
end

---@param side? string
---@param times? integer
---@param breakBlocks? boolean
function SimulatableSquirtle:move(side, times, breakBlocks)
    if self.simulate then
        self.timesMoved = self.timesMoved + 1
        return false
    else
        return self.squirtle:move(side, times, breakBlocks)
    end
end

---@param times? integer
---@param breakBlocks? boolean
function SimulatableSquirtle:forward(times, breakBlocks)
    return self:move("forward", times, breakBlocks)
end

---@param times? integer
---@param breakBlocks? boolean
function SimulatableSquirtle:up(times, breakBlocks)
    return self:move("up", times, breakBlocks)
end

---@param times? integer
---@param breakBlocks? boolean
function SimulatableSquirtle:down(times, breakBlocks)
    return self:move("down", times, breakBlocks)
end

---@param times? integer
---@param breakBlocks? boolean
function SimulatableSquirtle:back(times, breakBlocks)
    return self:move("back", times, breakBlocks)
end

---@param side? string
function SimulatableSquirtle:turn(side)
    if not self.simulate then
        self.squirtle:turn(side)
    end
end

---@param flag? boolean
function SimulatableSquirtle:flipTurns(flag)
    self.squirtle.flipTurns = flag or false
end

function SimulatableSquirtle:left()
    self:turn("left")
end

function SimulatableSquirtle:right()
    self:turn("right")
end

function SimulatableSquirtle:around()
    self:turn("back")
end

---@param side? string
---@param toolSide? string
function SimulatableSquirtle:dig(side, toolSide)
    if not self.simulate then
        self.squirtle:dig(side, toolSide)
    end
end

---@param block string
---@param side? string
function SimulatableSquirtle:place(block, side)
    if self.simulate then
        if not self.blocksPlaced[block] then
            self.blocksPlaced[block] = 0
        end

        self.blocksPlaced[block] = self.blocksPlaced[block] + 1
    else
        if not self.squirtle:select(block, true) then
            requireItems({[block] = 1})

            if not self.squirtle:select(block, true) then
                error("unexpected error")
            end
        end

        self.squirtle:place(side)
    end
end

return SimulatableSquirtle
