-- [todo] ❌ "models" shouldn't import from "apis"
local ItemApi = require "lib.apis.item-api"
local ItemStock = require "lib.models.item-stock"
local SimulationState = {}

---@class SimulationState
---@field fuel integer
---@field facing integer
---@field position Vector
---@field placed ItemStock
---@field water UsedFluidSimulationState
---@field lava UsedFluidSimulationState
---@field waterBalance integer?
---@field lavaBalance integer?
---
---@class UsedFluidSimulationState
---@field balance integer
---@field currentStreak integer
---@field highestStreak integer
---
---@class SimulationResults
---@field steps integer
---@field placed ItemStock
---@field water integer?
---@field lava integer?
---

---@param fuel integer
---@param facing integer
---@param position Vector
---@return SimulationState
function SimulationState.construct(fuel, facing, position)
    ---@type SimulationState
    local state = {
        facing = facing,
        fuel = fuel,
        position = position,
        placed = {},
        water = {balance = 0, currentStreak = 0, highestStreak = 0},
        lava = {balance = 0, currentStreak = 0, highestStreak = 0}
    }

    return state
end

---@param state SimulationState
---@param fuel integer
---@return SimulationResults
function SimulationState.getResults(state, fuel)
    if state.water.currentStreak > state.water.highestStreak then
        state.water.highestStreak = state.water.currentStreak
    end

    state.water.currentStreak = 0

    if state.lava.currentStreak > state.lava.highestStreak then
        state.lava.highestStreak = state.lava.currentStreak
    end

    state.lava.currentStreak = 0

    local requiredWaterBuckets = math.max(state.water.highestStreak, math.abs(state.water.balance))
    local requiredLavaBuckets = math.max(state.lava.highestStreak, math.abs(state.lava.balance))
    local placed = state.placed

    if requiredWaterBuckets > 0 then
        placed = ItemStock.add(placed, {[ItemApi.waterBucket] = requiredWaterBuckets})
    end

    if requiredLavaBuckets > 0 then
        placed = ItemStock.add(placed, {[ItemApi.lavaBucket] = requiredLavaBuckets})
    end

    ---@type SimulationResults
    local results = {placed = placed, steps = math.abs(fuel - state.fuel), lava = state.lavaBalance, water = state.waterBalance}

    return results
end

---@param state SimulationState
---@param block string
---@param quantity? integer
function SimulationState.recordPlacedBlock(state, block, quantity)
    state.placed[block] = (state.placed[block] or 0) + (quantity or 1)
end

---@param state SimulationState
---@param block string
---@param quantity? integer
function SimulationState.recordTakenBlock(state, block, quantity)
    state.placed[block] = (state.placed[block] or 0) - (quantity or 1)
end

---@param state SimulationState
function SimulationState.placeWater(state)
    state.water.balance = state.water.balance - 1
    state.water.currentStreak = state.water.currentStreak + 1
end

---@param state SimulationState
function SimulationState.takeWater(state)
    state.water.balance = state.water.balance + 1

    if state.water.currentStreak > state.water.highestStreak then
        state.water.highestStreak = state.water.currentStreak
    end

    state.water.currentStreak = 0
end

---@param state SimulationState
function SimulationState.placeLava(state)
    state.lava.balance = state.lava.balance - 1
    state.lava.currentStreak = state.lava.currentStreak + 1
end

---@param state SimulationState
function SimulationState.takeLava(state)
    state.lava.balance = state.lava.balance + 1

    if state.lava.currentStreak > state.lava.highestStreak then
        state.lava.highestStreak = state.lava.currentStreak
    end

    state.lava.currentStreak = 0
end

return SimulationState
