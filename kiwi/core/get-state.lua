local Vector = require "kiwi.core.vector"
local Cardinal = require "kiwi.core.cardinal"
-- local HomeOutput = requ
---@class KiwiState
---@field position KiwiVector
---@field facing integer
---@field output KiwiHomeOutput

---@type KiwiState
local state = {}

local stateFilePath = "/kiwi-state.json"
local loadedFromDisk = false

---@param data KiwiState
local function parse(data)
    ---@type KiwiState
    local state = {}

    if data.position then
        state.position = Vector.cast(data.position)
    end

    if data.facing and Cardinal.isCardinal(data.facing) then
        state.facing = data.facing
    end

    if data.output then
        -- local output = 
    end

    return state
end

local function loadFromDisk()
    if fs.exists(stateFilePath) then
        local file = fs.open(stateFilePath, "r")
        local stateOnDisk, message = textutils.unserializeJSON(file.readAll())
        file.close()

        if not stateOnDisk then
            error(message)
        end

        return parse(stateOnDisk)
    else
        error("no state file")
    end
end

local function writeToDisk(state)
    local file = fs.open(stateFilePath, "w")
    file.write(textutils.serializeJSON(state))
    file.close()
end

---@return KiwiState
return function()
    if not loadedFromDisk then
        if not fs.exists(stateFilePath) then
            writeToDisk(state)
        end

        local stateOnDisk = loadFromDisk()

        for key, value in pairs(stateOnDisk) do
            state[key] = value
        end

        loadedFromDisk = true
    end

    return state
end
