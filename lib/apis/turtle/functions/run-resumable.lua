local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ItemStock = require "lib.models.item-stock"
local DatabaseApi = require "lib.apis.database.database-api"

---@generic T
---@param TurtleApi TurtleApi
---@param name string
---@param args string[]
---@param start fun(args:string[], options?: TurtleResumableOptions) : T
---@param main fun(state: T) : unknown|nil
---@param resume fun(state: T) : unknown|nil
---@param finish fun(state: T) : unknown|nil
return function(TurtleApi, name, args, start, main, resume, finish)
    local success, message = pcall(function(...)
        local resumable = DatabaseApi.findTurtleResumable(name)

        if not resumable then
            ---@type TurtleResumableOptions
            local options = {}
            local state = start(args, options)

            if not state then
                return
            end

            Utils.writeStartupFile(name)
            local randomSeed = os.epoch("utc")
            math.randomseed(randomSeed)

            -- set up initial state for potential later shutdown recovery
            ---@type SimulationState
            local initialState = {
                facing = TurtleApi.getFacing(),
                fuel = TurtleApi.getNonInfiniteFuelLevel(),
                position = TurtleApi.getPosition()
            }

            local results = TurtleApi.simulate(function()
                main(state)
            end)

            TurtleApi.refuelTo(results.steps)
            local required = results.placed

            if options.additionalRequiredItems then
                required = ItemStock.add(required, options.additionalRequiredItems)
            end

            TurtleApi.requireItems(required, options.requireShulkers)
            local home = TurtleApi.getPosition()
            DatabaseApi.createTurtleResumable({
                name = name,
                initialState = initialState,
                randomSeed = randomSeed,
                home = home,
                args = args,
                state = state,
                options = options
            })
        else
            -- recover from shutdown
            print("[resume] ...")
            resume(resumable.state)
            math.randomseed(resumable.randomSeed)
            TurtleApi.cleanup() -- replaces recover()

            local initialState = resumable.initialState
            -- enable simulation so that the later call to main() gets simulated until
            -- it reaches the state the turtle was in when it shut off
            TurtleApi.resume(initialState.fuel, initialState.facing, initialState.position)
        end

        resumable = DatabaseApi.getTurtleResumable(name)

        local aborted = EventLoop.runUntil(string.format("%s:abort", name), function()
            main(resumable.state)
        end)

        if aborted then
            -- [todo] it is possible that the cached position/facing is no longer valid due to abortion.
            TurtleApi.cleanup()
        end

        finish(resumable.state)
        DatabaseApi.deleteTurtleResumable(name)
        Utils.deleteStartupFile()
    end)

    return success, message
end
