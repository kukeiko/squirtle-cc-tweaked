local selectItem = require "squirtle.backpack.select-item"
local move = require "squirtle.move"
local turn = require "squirtle.turn"
local place = require "squirtle.place"
local dig = require "squirtle.dig"

---@class Squirtle
---@field flipTurns boolean
local Squirtle = {}

---@return Squirtle
function Squirtle:new()
    ---@type Squirtle
    local instance = {flipTurns = false}

    return setmetatable(instance, {__index = self})
end

---@param side? string
---@param times? integer
---@param breakBlocks? boolean
---@return boolean
function Squirtle:move(side, times, breakBlocks)
    return move(side, times, breakBlocks)
end

---@param side? string
function Squirtle:turn(side)
    if self.flipTurns then
        if side == "left" then
            side = "right"
        elseif side == "right" then
            side = "left"
        end
    end

    turn(side)
end

---@param side? string
---@param toolSide? string
function Squirtle:dig(side, toolSide)
    dig(side, toolSide)
end

---@param name string
---@param exact? boolean
---@return false|integer
function Squirtle:select(name, exact)
    return selectItem(name, exact)
end

---@param side? string
function Squirtle:place(side)
    return place(side)
end

return Squirtle
