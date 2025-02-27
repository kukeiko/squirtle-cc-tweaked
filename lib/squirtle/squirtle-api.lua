local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local World = require "lib.models.world"
local ItemStock = require "lib.models.item-stock"
local DatabaseApi = require "lib.apis.database-api"
local findPath = require "lib.squirtle.find-path"
local Inventory = require "lib.apis.inventory-api"
local Cardinal = require "lib.models.cardinal"
local Vector = require "lib.models.vector"
local State = require "lib.squirtle.state"
local SquirtleElementalApi = require "lib.squirtle.api-layers.squirtle-elemental-api"
local Basic = require "lib.squirtle.api-layers.squirtle-basic-api"
local Advanced = require "lib.squirtle.api-layers.squirtle-advanced-api"
local Complex = require "lib.squirtle.api-layers.squirtle-complex-api"

---@class SquirtleApi : SquirtleComplexApi
local SquirtleApi = {}
setmetatable(SquirtleApi, {__index = Complex})

--- [todo] rework to not accept a predicate. also somehow support block tags (see isCrops() from farmer)
---@param predicate? (fun(block: Block) : boolean) | string[]
---@return fun() : nil
function SquirtleApi.setBreakable(predicate)
    return State.setBreakable(predicate)
end

---@param side string
---@return boolean success if everything could be dumped
function SquirtleApi.dump(side)
    local items = SquirtleApi.getStacks()

    for slot in pairs(items) do
        SquirtleApi.select(slot)
        SquirtleApi.drop(side)
    end

    return SquirtleApi.isEmpty()
end

function SquirtleApi.lookAtChest()
    SquirtleApi.turn(Inventory.findChest())
end

---@param target Vector
---@return boolean, string?
function SquirtleApi.tryMoveToPoint(target)
    local delta = Vector.minus(target, SquirtleApi.getPosition())

    if delta.y > 0 then
        if not SquirtleApi.tryMove("top", delta.y) then
            return false, "top"
        end
    elseif delta.y < 0 then
        if not SquirtleApi.tryMove("bottom", -delta.y) then
            return false, "bottom"
        end
    end

    if delta.x > 0 then
        SquirtleApi.face(Cardinal.east)
        if not SquirtleApi.tryMove("front", delta.x) then
            return false, "front"
        end
    elseif delta.x < 0 then
        SquirtleApi.face(Cardinal.west)
        if not SquirtleApi.tryMove("front", -delta.x) then
            return false, "front"
        end
    end

    if delta.z > 0 then
        SquirtleApi.face(Cardinal.south)

        if not SquirtleApi.tryMove("front", delta.z) then
            return false, "front"
        end
    elseif delta.z < 0 then
        SquirtleApi.face(Cardinal.north)

        if not SquirtleApi.tryMove("front", -delta.z) then
            return false, "front"
        end
    end

    return true
end

---@param path Vector[]
---@return boolean, string?, integer?
local function movePath(path)
    for i, next in ipairs(path) do
        local success, failedSide = SquirtleApi.tryMoveToPoint(next)

        if not success then
            return false, failedSide, i
        end
    end

    return true
end

---@param to Vector
---@param world? World
---@param breakable? function
function SquirtleApi.navigate(to, world, breakable)
    breakable = breakable or function()
        return false
    end

    local restoreBreakable = SquirtleApi.setBreakable(breakable)

    if not world then
        local position = SquirtleElementalApi.getPosition()
        world = World.create(position.x, position.y, position.z)
    end

    local from = SquirtleElementalApi.getPosition()
    local facing = SquirtleElementalApi.getFacing()

    while true do
        local path, msg = findPath(from, to, facing, world)

        if not path then
            restoreBreakable()
            return false, msg
        end

        local distance = Vector.manhattan(from, to)
        Advanced.refuelTo(distance)
        local success, failedSide = movePath(path)

        if success then
            restoreBreakable()
            return true
        elseif failedSide then
            from = SquirtleElementalApi.getPosition()
            facing = SquirtleElementalApi.getFacing()
            local scannedLocation = Vector.plus(from, Cardinal.toVector(Cardinal.fromSide(failedSide, facing)))
            World.setBlock(world, scannedLocation)
        end
    end
end

---@param checkEarlyExit? fun() : boolean
---@return boolean
function SquirtleApi.navigateTunnel(checkEarlyExit)
    local forbidden

    while true do
        local strategy

        if SquirtleApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        elseif forbidden ~= "up" and SquirtleApi.tryWalk("up") then
            strategy = "up"
            forbidden = "down"
        elseif forbidden ~= "down" and SquirtleApi.tryWalk("down") then
            strategy = "down"
            forbidden = "up"
        elseif SquirtleApi.turn("left") and SquirtleApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        elseif SquirtleApi.turn("left") and forbidden ~= "back" and SquirtleApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        elseif SquirtleApi.turn("left") and SquirtleApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        else
            return true
        end

        if strategy == "forward" then
            while SquirtleApi.tryWalk("forward") do
            end
        elseif strategy == "up" then
            while SquirtleApi.tryWalk("up") do
            end
        elseif strategy == "down" then
            while SquirtleApi.tryWalk("down") do
            end
        end

        if checkEarlyExit ~= nil and checkEarlyExit() then
            return checkEarlyExit()
        end
    end
end

---@param initial SimulationDetails?
---@param target SimulationDetails?
function SquirtleApi.simulate(initial, target)
    State.simulate = true
    State.simulation.initial = initial
    State.simulation.target = target

    if initial then
        State.simulation.current = Utils.clone(initial)
    else
        State.simulation.current = nil
    end

    State.checkResumeEnd()
end

---@class SquirtleConfigOptions
---@field orientate? "move"|"disk-drive"
---@field breakDirection? "top"|"front"|"bottom"
---@field shulkerSides? PlaceSide[]
---@param options SquirtleConfigOptions
function SquirtleApi.configure(options)
    if options.orientate then
        State.orientationMethod = options.orientate
    end

    if options.breakDirection then
        State.breakDirection = options.breakDirection
    end

    if options.shulkerSides then
        State.shulkerSides = options.shulkerSides
    end
end

function SquirtleApi.recover()
    local shulkerDirections = {"top", "bottom", "front"}

    for _, direction in pairs(shulkerDirections) do
        if Basic.probe(direction, "minecraft:shulker_box") then
            Basic.dig(direction)
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
function SquirtleApi.runResumable(name, args, start, main, resume, finish, additionalRequiredItems)
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
            ---@type SimulationDetails
            local initialState = {
                facing = SquirtleElementalApi.getFacing(),
                fuel = SquirtleElementalApi.getNonInfiniteFuelLevel(),
                position = SquirtleElementalApi.getPosition()
            }

            State.simulate = true
            State.simulation.current = Utils.clone(initialState)
            main(state)
            State.simulate = false
            State.simulation.current = nil
            Advanced.refuelTo(State.results.steps)
            local required = State.results.placed

            if additionalRequiredItems then
                required = ItemStock.add(required, additionalRequiredItems)
            end

            SquirtleApi.requireItems(required, true)
            local home = SquirtleElementalApi.getPosition()
            DatabaseApi.createSquirtleResumable({
                name = name,
                initialState = initialState,
                randomSeed = randomSeed,
                home = home,
                args = args,
                state = state
            })
        else
            print("[resume] ...")
            resume(resumable.state)
            -- recover from shutdown
            math.randomseed(resumable.randomSeed)
            Complex.cleanup() -- replaces recover()

            local initialState = resumable.initialState
            ---@type SimulationDetails
            local targetState = {
                facing = SquirtleElementalApi.getFacing(),
                fuel = SquirtleElementalApi.getNonInfiniteFuelLevel(),
                position = SquirtleElementalApi.getPosition()
            }

            print("[simulate] to target state...")
            SquirtleApi.simulate(initialState, targetState)
            print("[simulate] done!")
        end

        resumable = DatabaseApi.getSquirtleResumable(name)

        local aborted = EventLoop.runUntil(string.format("%s:abort", name), function()
            main(resumable.state)
        end)

        if aborted then
            -- [todo] it is possible that the cached position/facing is no longer valid due to abortion.
            Complex.cleanup()
        end

        finish(resumable.state)
        DatabaseApi.deleteSquirtleResumable(name)
        Utils.deleteStartupFile()
    end)

    return success, message
end

return SquirtleApi
