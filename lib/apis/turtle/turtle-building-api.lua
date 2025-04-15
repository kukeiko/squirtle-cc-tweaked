local getNative = require "lib.apis.turtle.functions.get-native"
local SquirtleState = require "lib.squirtle.state"
local TurtleStateApi = require "lib.apis.turtle.turtle-state-api"
local TurtleMiningApi = require "lib.apis.turtle.turtle-mining-api"
local TurtleInventoryApi = require "lib.apis.turtle.turtle-inventory-api"
local TurtleSharedApi = require "lib.apis.turtle.turtle-shared-api"

---@class TurtleBuildingApi
local TurtleBuildingApi = {}

---@param direction? string
---@param text? string
---@return boolean, string?
function TurtleBuildingApi.place(direction, text)
    if TurtleStateApi.isSimulating() then
        return true
    end

    direction = direction or "front"
    return getNative("place", direction)(text)
end

---@param directions PlaceSide[]
---@return string? placedDirection
function TurtleBuildingApi.placeAtOneOf(directions)
    for i = 1, #directions do
        if TurtleBuildingApi.place(directions[i]) then
            return directions[i]
        end
    end
end

---@return string? direction
function TurtleBuildingApi.placeTopOrBottom()
    local directions = {"top", "bottom"}

    for _, direction in pairs(directions) do
        if TurtleBuildingApi.place(direction) then
            return direction
        end
    end
end

---@return string? direction
function TurtleBuildingApi.placeFrontTopOrBottom()
    local directions = {"front", "top", "bottom"}

    for _, direction in pairs(directions) do
        if TurtleBuildingApi.place(direction) then
            return direction
        end
    end
end

---@param side? string
---@param text? string
---@return boolean, string?
function TurtleBuildingApi.tryReplace(side, text)
    if TurtleStateApi.isSimulating() then
        return true
    end

    if TurtleBuildingApi.place(side, text) then
        return true
    end

    while TurtleMiningApi.tryMine(side) do
    end

    return TurtleBuildingApi.place(side, text)
end

---@param sides? string[]
---@param text? string
---@return string?
function TurtleBuildingApi.tryReplaceAtOneOf(sides, text)
    if TurtleStateApi.isSimulating() then
        error("tryReplaceAtOneOf() can't be simulated")
    end

    sides = sides or {"top", "front", "bottom"}

    for i = 1, #sides do
        local side = sides[i]

        if TurtleBuildingApi.place(side, text) then
            return side
        end
    end

    -- [todo] tryPut() is attacking - should we do it here as well?
    for i = 1, #sides do
        local side = sides[i]

        while TurtleMiningApi.tryMine(side) do
        end

        if TurtleBuildingApi.place(side, text) then
            return side
        end
    end
end

---@param block? string
---@return boolean
local function simulateTryPut(block)
    -- [todo] use TurtleStateApi
    if block then
        if not SquirtleState.results.placed[block] then
            SquirtleState.results.placed[block] = 0
        end

        SquirtleState.results.placed[block] = SquirtleState.results.placed[block] + 1
    end

    return true
end

---@param block? string
local function simulatePut(block)
    simulateTryPut(block)
end

---@param side? string
---@param block? string
---@return boolean
function TurtleBuildingApi.tryPut(side, block)
    side = side or "front"
    local native = getNative("place", side)

    if TurtleStateApi.isSimulating() then
        return simulateTryPut(block)
    end

    if block then
        while not TurtleInventoryApi.selectItem(block) do
            TurtleSharedApi.requireItems({[block] = 1})
        end
    end

    if native() then
        return true
    end

    while TurtleMiningApi.tryMine(side) do
    end

    -- [todo] band-aid fix
    while turtle.attack() do
        os.sleep(1)
    end

    return native()
end

---@param side? string
---@param block? string
function TurtleBuildingApi.put(side, block)
    if TurtleStateApi.isSimulating() then
        return simulatePut(block)
    end

    if not TurtleBuildingApi.tryPut(side, block) then
        error("failed to place")
    end
end

---@param sides? PlaceSide[]
---@param block? string
---@return PlaceSide? placedDirection
function TurtleBuildingApi.tryPutAtOneOf(sides, block)
    if TurtleStateApi.isSimulating() then
        -- [todo] reconsider if this method should really be simulatable, as its outcome depends on world state
        return simulatePut(block)
    end

    sides = sides or {"top", "front", "bottom"}

    if block then
        while not TurtleInventoryApi.selectItem(block) do
            TurtleSharedApi.requireItem(block)
        end
    end

    for i = 1, #sides do
        local native = getNative("place", sides[i])

        if native() then
            return sides[i]
        end
    end

    -- [todo] tryPut() is attacking - should we do it here as well?
    for i = 1, #sides do
        local native = getNative("place", sides[i])

        while TurtleMiningApi.tryMine(sides[i]) do
        end

        if native() then
            return sides[i]
        end
    end
end

return TurtleBuildingApi
