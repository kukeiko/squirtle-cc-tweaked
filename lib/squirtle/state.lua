local Cardinal = require "elements.cardinal"
local Vector = require "elements.vector"

---@class Simulated
---@field steps integer
---@field placed table<string, integer>
local SimulationResults = {placed = {}, steps = 0}

---@class State
---@field breakable? fun(block: Block) : boolean
---@field facing integer
---@field position Vector
---@field flipTurns boolean
---@field simulate boolean
---@field results Simulated
local State = {facing = Cardinal.south, position = Vector.create(0, 0, 0), flipTurns = false, simulate = false, results = SimulationResults}

---@param block Block
---@return boolean
local breakableSafeguard = function(block)
    return block.name ~= "minecraft:bedrock"
end

---@param block Block
---@return boolean
function State.canBreak(block)
    return breakableSafeguard(block) and (State.breakable == nil or State.breakable(block))
end

---@param predicate? (fun(block: Block) : boolean) | string[]
---@return fun() : nil
function State.setBreakable(predicate)
    local current = State.breakable

    local function restore()
        State.breakable = current
    end

    if type(predicate) == "table" then
        State.breakable = function(block)
            for _, item in pairs(predicate) do
                if block.name == item then
                    return true
                end
            end

            return false
        end
    else
        State.breakable = predicate
    end

    return restore
end

return State
