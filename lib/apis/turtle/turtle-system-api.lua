local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ItemStock = require "lib.models.item-stock"
local DatabaseApi = require "lib.apis.database.database-api"
local TurtleStateApi = require "lib.apis.turtle.turtle-state-api"
local TurtleInventoryApi = require "lib.apis.turtle.turtle-inventory-api"
local TurtleMiningApi = require "lib.apis.turtle.turtle-mining-api"
local TurtleMovementApi = require "lib.apis.turtle.turtle-movement-api"
local TurtleSharedApi = require "lib.apis.turtle.turtle-shared-api"

---@class TurtleSystemApi
local TurtleSystemApi = {}

function TurtleSystemApi.cleanup()
    local diskState = DatabaseApi.getSquirtleDiskState()

    -- [todo] what is the difference between cleanupSides & diskDriveSides/shulkerSides?
    for side, block in pairs(diskState.cleanupSides) do
        if TurtleMiningApi.probe(side, block) then
            TurtleInventoryApi.selectEmpty()
            TurtleMiningApi.dig(side)
        end
    end

    for i = 1, #diskState.diskDriveSides do
        local side = diskState.diskDriveSides[i]
        TurtleInventoryApi.selectEmpty()

        if TurtleMiningApi.probe(side, "computercraft:disk_drive") then
            TurtleMiningApi.dig(side)
            break
        end
    end

    for i = 1, #diskState.shulkerSides do
        local side = diskState.shulkerSides[i]
        TurtleInventoryApi.selectEmpty()

        if TurtleMiningApi.probe(side, "minecraft:shulker_box") then
            TurtleMiningApi.dig(side)
            break
        end
    end

    diskState.cleanupSides = {}
    diskState.diskDriveSides = {}
    diskState.shulkerSides = {}
    DatabaseApi.saveSquirtleDiskState(diskState)
end

function TurtleSystemApi.recover()
    local shulkerDirections = {"top", "bottom", "front"}

    for _, direction in pairs(shulkerDirections) do
        if TurtleMiningApi.probe(direction, "minecraft:shulker_box") then
            TurtleMiningApi.dig(direction)
        end
    end
end

---@generic T
---@param name string
---@param args string[]
---@param start fun(args:string[]) : T
---@param main fun(state: T) : unknown|nil
---@param resume fun(state: T) : unknown|nil
---@param finish fun(state: T) : unknown|nil
---@param additionalRequiredItems? ItemStock
function TurtleSystemApi.runResumable(name, args, start, main, resume, finish, additionalRequiredItems)
    local success, message = pcall(function(...)
        local resumable = DatabaseApi.findSquirtleResumable(name)

        if not resumable then
            local state = start(args)

            if not state then
                return
            end

            Utils.writeStartupFile(name)
            local randomSeed = os.epoch("utc")
            math.randomseed(randomSeed)

            -- set up initial state for potential later shutdown recovery
            ---@type SimulationState
            local initialState = {
                facing = TurtleStateApi.getFacing(),
                fuel = TurtleStateApi.getNonInfiniteFuelLevel(),
                position = TurtleStateApi.getPosition()
            }

            -- [todo] old code left for reference in case refactor broke something
            -- simulate main() to capture required fuel & items
            -- State.simulate = true
            -- State.simulation.current = Utils.clone(initialState)
            -- main(state)
            -- State.simulate = false
            -- State.simulation.current = nil
            TurtleStateApi.beginSimulation()
            local results = TurtleStateApi.endSimulation()
            TurtleMovementApi.refuelTo(results.steps)
            local required = results.placed

            if additionalRequiredItems then
                required = ItemStock.add(required, additionalRequiredItems)
            end

            TurtleSharedApi.requireItems(required, true)
            local home = TurtleStateApi.getPosition()
            DatabaseApi.createSquirtleResumable({
                name = name,
                initialState = initialState,
                randomSeed = randomSeed,
                home = home,
                args = args,
                state = state
            })
        else
            -- recover from shutdown
            print("[resume] ...")
            resume(resumable.state)
            math.randomseed(resumable.randomSeed)
            TurtleSystemApi.cleanup() -- replaces recover()

            local initialState = resumable.initialState
            ---@type SimulationState
            local targetState = {
                facing = TurtleStateApi.getFacing(),
                fuel = TurtleStateApi.getNonInfiniteFuelLevel(),
                position = TurtleStateApi.getPosition()
            }

            -- enable simulation so that the later call to main() gets simulated until
            -- it reaches the state the turtle was in when it shut off
            print("[simulate] enabling simulation...")
            -- TurtleSystemApi.simulate(initialState, targetState)
            TurtleStateApi.beginSimulation(initialState, targetState)
        end

        resumable = DatabaseApi.getSquirtleResumable(name)

        local aborted = EventLoop.runUntil(string.format("%s:abort", name), function()
            main(resumable.state)
        end)

        if aborted then
            -- [todo] it is possible that the cached position/facing is no longer valid due to abortion.
            TurtleSystemApi.cleanup()
        end

        finish(resumable.state)
        DatabaseApi.deleteSquirtleResumable(name)
        Utils.deleteStartupFile()
    end)

    return success, message
end

return TurtleSystemApi
