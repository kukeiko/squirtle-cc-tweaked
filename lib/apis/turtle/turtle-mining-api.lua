local Utils = require "lib.tools.utils"
local TurtleStateApi = require "lib.apis.turtle.turtle-state-api"
local getNative = require "lib.apis.turtle.functions.get-native"

---@class TurtleMiningApi
local TurtleMiningApi = {}

---Returns the block towards the given direction. If a name is given, the block has to match it or nil is returned.
---"name" can either be a string or a table of strings.
---@param direction? string
---@param name? table|string
---@return Block? block
function TurtleMiningApi.probe(direction, name)
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
---@param tool? string
---@return boolean, string?
function TurtleMiningApi.dig(direction, tool)
    if TurtleStateApi.isSimulating() then
        return true
    end

    direction = direction or "forward"
    return getNative("dig", direction)(tool)
end

---@param directions DigSide[]
---@return string? dugDirection
function TurtleMiningApi.digAtOneOf(directions)
    for i = 1, #directions do
        if TurtleMiningApi.dig(directions[i]) then
            return directions[i]
        end
    end
end

---Throws an error if:
--- - no digging tool is equipped
---@param direction? string
---@return boolean success, string? error
function TurtleMiningApi.tryMine(direction)
    if TurtleStateApi.isSimulating() then
        return true
    end

    direction = direction or "forward"
    local native = getNative("dig", direction)
    local block = TurtleMiningApi.probe(direction)

    if not block then
        return false
    elseif not TurtleStateApi.canBreak(block) then
        return false, string.format("not allowed to mine block %s", block.name)
    end

    local success, message = native()

    if not success then
        if message == "Nothing to dig here" then
            return false
        elseif string.match(message, "tool") then
            error(string.format("failed to mine %s: %s", direction, message))
        end
    end

    return success, message
end

---Throws an error if:
--- - no digging tool is equipped
--- - turtle is not allowed to dig the block
---@param direction? string
---@return boolean success
function TurtleMiningApi.mine(direction)
    local success, message = TurtleMiningApi.tryMine(direction)

    -- if there is no message, then there just wasn't anything to dig, meaning every other case is interpreted as an error
    if not success and message then
        error(message)
    end

    return success
end

return TurtleMiningApi
