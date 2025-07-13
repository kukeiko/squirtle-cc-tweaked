local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ItemStock = require "lib.models.item-stock"
local DatabaseApi = require "lib.apis.database.database-api"
local TurtleApi = require "lib.apis.turtle.turtle-api"

---@class ResumableFn
---@field name string
---@field isSimulatable boolean
---@field fn fun(state: table) : table
---
---@class Resumable
---@field name string
---@field startFn? fun(args: string[], options: TurtleResumableOptions) : table
---@field resumeFn? fun(state: table, resumed: string) : nil
---@field finishFn? fun(state: table, aborted: boolean) : nil
---@field resumableFns ResumableFn[]
local Resumable = {}

---@param name string
---@return Resumable
function Resumable.new(name)
    ---@type Resumable
    local instance = {name = name, resumableFns = {}}
    setmetatable(instance, {__index = Resumable})

    return instance
end

---@param fn fun(args: string[], options: TurtleResumableOptions) : table?
function Resumable:setStart(fn)
    self.startFn = fn
end

---@param fn fun(state: table, resumed: string) : table?
function Resumable:setResume(fn)
    self.resumeFn = fn
end

---@param fn fun(state: table, aborted: boolean) : any
function Resumable:setFinish(fn)
    self.finishFn = fn
end

---@param name string
---@param fn fun(state: table) : table?
function Resumable:addMain(name, fn)
    -- [todo] ❌ throw if duplicate name
    ---@type ResumableFn
    local resumableFn = {name = name, isSimulatable = false, fn = fn}
    table.insert(self.resumableFns, resumableFn)
end

---@param name string
---@param fn fun(state: table) : table?
function Resumable:addSimulatableMain(name, fn)
    -- [todo] ❌ throw if duplicate name
    ---@type ResumableFn
    local resumableFn = {name = name, isSimulatable = true, fn = fn}
    table.insert(self.resumableFns, resumableFn)
end

---@return SimulationState
local function getSimulationState()
    return {facing = TurtleApi.getFacing(), fuel = TurtleApi.getNonInfiniteFuelLevel(), position = TurtleApi.getPosition()}
end

---@param self Resumable
---@param args string[]
---@return boolean
local function bootstrap(self, args)
    ---@type TurtleResumableOptions
    local options = {}
    local state = self.startFn and self.startFn(args, options)

    if self.startFn and not state then
        return false
    end

    state = state or {}
    local randomSeed = os.epoch("utc")
    math.randomseed(randomSeed)

    local results = TurtleApi.simulate(function()
        for _, resumableFn in ipairs(self.resumableFns) do
            if resumableFn.isSimulatable then
                -- [todo] ❓ if an app makes use of using the returned state of one function for the next, this right here might become an issue
                -- as we're skipping functions that are not simulatable.
                state = resumableFn.fn(state) or state
            end
        end
    end)

    if options.requireFuel then
        TurtleApi.refuelTo(results.steps)
    end

    if options.requireItems then
        local required = results.placed

        if options.additionalRequiredItems then
            required = ItemStock.add(required, options.additionalRequiredItems)
        end

        TurtleApi.requireItems(required, options.requireShulkers)
    end

    DatabaseApi.createTurtleResumable({
        name = self.name,
        initialState = getSimulationState(),
        randomSeed = randomSeed,
        home = TurtleApi.getPosition(),
        args = args,
        state = state,
        options = options
    })

    return true
end

---@param self Resumable
---@param resumable TurtleResumable
---@return integer?
local function resume(self, resumable)
    TurtleApi.cleanup()

    if self.resumeFn and resumable.fnName then
        self.resumeFn(resumable.state, resumable.fnName)
    end

    math.randomseed(resumable.randomSeed)

    if not resumable.fnName then
        return nil
    end

    local resumableFn = Utils.find(self.resumableFns, function(item)
        return item.name == resumable.fnName
    end)

    if not resumableFn then
        error(string.format("resumable fn() named %s not found", resumable.fnName))
    end

    if resumableFn.isSimulatable then
        local initialState = resumable.initialState
        -- enable simulation so that the later call to main() gets simulated until
        -- it reaches the state the turtle was in when it shut off
        TurtleApi.resume(initialState.fuel, initialState.facing, initialState.position)
        resumableFn.fn(resumable.state)

        if TurtleApi.isResuming() then
            error("failed to resume")
        end

        return Utils.indexOf(self.resumableFns, resumableFn) + 1
    else
        return Utils.indexOf(self.resumableFns, resumableFn)
    end
end

---@param args? string[]
---@param loop? boolean
function Resumable:run(args, loop)
    args = args or {}
    local resumable = DatabaseApi.findTurtleResumable(self.name)
    ---@type integer?
    local fnIndex

    if not resumable then
        if not bootstrap(self, args) then
            return
        end
    else
        fnIndex = resume(self, resumable)
    end

    resumable = DatabaseApi.getTurtleResumable(self.name)

    local aborted = EventLoop.runUntil(string.format("%s:abort", self.name), function()
        while true do
            for i, resumableFn in ipairs(self.resumableFns) do
                if not fnIndex or (fnIndex and i >= fnIndex) then
                    resumable.fnName = resumableFn.name
                    resumable.initialState = getSimulationState()
                    DatabaseApi.updateTurtleResumable(resumable)
                    resumable.state = resumableFn.fn(resumable.state) or resumable.state
                end
            end

            if not loop then
                break
            end

            fnIndex = nil
        end
    end)

    if aborted then
        -- [todo] ❓ is it possible that the cached position/facing is no longer valid when aborting?
        TurtleApi.cleanup()
    end

    if self.finishFn then
        self.finishFn(resumable.state, aborted)
    end

    DatabaseApi.deleteTurtleResumable(self.name)
end

return Resumable
