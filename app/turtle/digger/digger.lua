package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Utils = require "utils"
local Side = require "elements.side"
local Vectors = require "elements.vector"
local World = require "geo.world"
local Chest = require "world.chest"
local Backpack = require "squirtle.backpack"
local navigate = require "squirtle.navigate"
local locate = require "squirtle.locate"
local boot = require "digger.boot"
local pushOutput = require "squirtle.transfer.push-output"
local pullInput = require "squirtle.transfer.pull-input"
local dump = require "squirtle.dump"
local Inventory = require "squirtle.inventory"
local Fuel = require "squirtle.fuel"
local suckSlotFromChest = require "squirtle.transfer.suck-slot-from-chest"

---@class DiggerAppState
---@field home Vector
---@field world World
---@field start Vector
---@field checkpoint Vector
---@field mineable table<string, unknown>

---@param point Vector
---@param world World
---@param start Vector
local function nextPoint(point, world, start)
    local delta = Vectors.create(0, 0, 0)

    if start.x == world.x then
        delta.x = 1
    elseif start.x == world.x + world.width - 1 then
        delta.x = -1
    end

    if start.z == world.z then
        delta.z = 1
    elseif start.z == world.z + world.depth - 1 then
        delta.z = -1
    end

    if start.y == world.y then
        delta.y = 1
    elseif start.y == world.y + world.height - 1 then
        delta.y = -1
    end

    local relative = Vectors.minus(point, start)

    if relative.z % 2 == 1 then
        delta.x = delta.x * -1
    end

    if relative.y % 2 == 1 then
        delta.x = delta.x * -1
        delta.z = delta.z * -1
    end

    if World.isInBoundsX(world, point.x + delta.x) then
        return Vectors.plus(point, Vectors.create(delta.x, 0, 0))
    elseif World.isInBoundsZ(world, point.z + delta.z) then
        return Vectors.plus(point, Vectors.create(0, 0, delta.z))
    elseif World.isInBoundsY(world, point.y + delta.y) then
        return Vectors.plus(point, Vectors.create(0, delta.y, 0))
    else
        Utils.prettyPrint(delta)
        print("reached the end")
        return false -- reached the end
    end
end

-- [todo] copied from farmer.lua
---@param bufferSide integer
---@param fuel integer
local function refuelFromBuffer(bufferSide, fuel)
    print("refueling, have", Fuel.getFuelLevel())
    Inventory.selectFirstEmptySlot()

    for slot, stack in pairs(Chest.getStacks(bufferSide)) do
        if stack.name == "minecraft:charcoal" then
            suckSlotFromChest(bufferSide, slot)
            Fuel.refuel() -- [todo] should provide count to not consume a whole stack
        end

        if Fuel.getFuelLevel() >= fuel then
            break
        end
    end

    print("refueled to", Fuel.getFuelLevel())

    -- in case we reached fuel limit and now have charcoal in the inventory
    if not dump(bufferSide) then
        error("buffer barrel full")
    end
end

-- [todo] idea: use output stacks of i/o chest to program which blocks are allowed to be mined.
-- (need to consider special case of stone => cobblestone)
-- for the non io version of this app (which should be a version i should build to make it easier
-- for others to use this app), we could let the player program blocks to mine via placing
-- them into inventory
local function main(args)
    print("booting...")
    local state = boot()
    print("booted!")

    local function isBreakable(block)
        return state.mineable[block.name]
    end

    if not state.checkpoint then
        print("no checkpoint, assuming digging is finished, going home ...")
        navigate(state.home, nil, isBreakable)
        print("done & home <3")

        return
    end

    local position = locate()

    if not World.isInBounds(state.world, position) then
        print("not inside digging area, going there now...")
        -- [todo] goto start first instead (and then to checkpoint) - if digging area is further away the turtle might otherwise
        -- start making new tunnels to get to checkpoint
        navigate(state.start, nil, isBreakable)
        print("at start! going to checkpoint...")
        navigate(state.checkpoint, nil, isBreakable)
        print("should be inside digging area again!")
    end

    local point = state.checkpoint
    local previous = point
    local maxFailedNavigates = state.world.width * state.world.depth
    local numFailedNavigates = 0
    Inventory.selectSlot(1)

    while point do
        if previous.y ~= point.y then
            print("saving checkpoint at", point)
            state.checkpoint = point
            Utils.saveAppState(state, "digger")
        end

        local moved, msg = navigate(point, state.world, isBreakable)

        if not moved then
            numFailedNavigates = numFailedNavigates + 1
            print(msg, numFailedNavigates)

            -- [todo] for this to work reliably, we would need to save numFailedNavigates
            -- to disk after each step, which is not something i want to do
            if numFailedNavigates >= maxFailedNavigates then
                print("can't dig further, going home")
                navigate(state.home, nil, isBreakable)
                error(
                    "todo: implement 'blocked to dig further' case, which should allow for reprogramming minable blocks")
            end
        else
            numFailedNavigates = 0
        end

        previous = point
        point = nextPoint(point, state.world, state.start)

        local gettingFull = Backpack.getStack(16) ~= nil
        local lowFuel = Fuel.getFuelLevel() < 1000
        local minFuel = 1200
        local buffer = Side.top

        if gettingFull or lowFuel then
            if gettingFull then
                print("getting full! going going home to dump inventory")
            elseif lowFuel then
                print("low on fuel! going home to get some")
            end

            print("saving checkpoint at", point)
            state.checkpoint = point
            Utils.saveAppState(state, "digger")
            navigate(state.home, nil, isBreakable)

            if not dump(buffer) then
                error("buffer full")
            end

            local io = Chest.findSide()

            if not pushOutput(buffer, io) then
                print("output full, waiting for it to drain...")

                repeat
                    os.sleep(7)
                until pushOutput(buffer, io)
            end

            while Fuel.getFuelLevel() < minFuel do
                print("trying to refuel to ", minFuel, ", have", Fuel.getFuelLevel())
                pullInput(io, buffer)
                refuelFromBuffer(buffer, minFuel)

                if Fuel.getFuelLevel() < minFuel then
                    os.sleep(3)
                end
            end

            print("unloaded all and have enough fuel - back to work!")
            Inventory.selectSlot(1)
            navigate(state.checkpoint, nil, isBreakable)
        end
    end

    print("all done! going home...")
    state.checkpoint = nil
    Utils.saveAppState(state, "digger")
    navigate(state.home)
    print("done & home <3")
end

main(arg)
