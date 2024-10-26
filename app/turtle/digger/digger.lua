package.path = package.path .. ";/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Utils = require "lib.common.utils"
local Vectors = require "lib.common.vector"
local World = require "lib.common.world"
local Squirtle = require "lib.squirtle.squirtle-api"
local AppState = require "lib.common.app-state"
local boot = require "digger.boot"
local Inventory = require "lib.inventory.inventory-api"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"

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
        -- delta.y = 1
        -- delta.y = 3
        delta.y = 5
    elseif start.y == world.y + world.height - 1 then
        -- delta.y = -1
        -- delta.y = -3
        delta.y = -5
    end

    if not World.isInBoundsY(world, point.y + delta.y) then
        -- delta.y = delta.y / 3
        delta.y = delta.y / 5
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
---@param buffer string
---@param fuel integer
local function refuelFromBuffer(buffer, fuel)
    print("refueling, have", Squirtle.getFuelLevel())
    Squirtle.selectFirstEmpty()

    for slot, stack in pairs(InventoryPeripheral.getStacks(buffer)) do
        if stack.name == "minecraft:charcoal" then
            Squirtle.suckSlot(buffer, slot)
            Squirtle.refuel() -- [todo] should provide count to not consume a whole stack
        end

        if Squirtle.hasFuel(fuel) then
            break
        end
    end

    print("refueled to", Squirtle.getFuelLevel())

    -- in case we reached fuel limit and now have charcoal in the inventory
    if not Squirtle.dump(buffer) then
        error("buffer barrel full")
    end
end

---@param state DiggerAppState
local function saveState(state)
    local blocks = state.world.blocked
    -- need to clear all blocks, otherwise disk gets full
    state.world.blocked = {}
    AppState.save(state, "digger")
    state.world.blocked = blocks
end

-- [todo] idea: use output stacks of i/o chest to program which blocks are allowed to be mined.
-- (need to consider special case of stone => cobblestone)
-- for the non io version of this app (which should be a version i should build to make it easier
-- for others to use this app), we could let the player program blocks to mine via placing
-- them into inventory
local function main(args)
    if args[1] == "io" then
        print("[digger v1.3.0] booting in I/O mode...")
    else
        print("[digger v1.3.0] booting in simple mode...")
    end

    local state = boot()
    print("booted!")

    local function isBreakable(block)
        if not block then
            return false
        end

        return state.mineable[block.name]
    end

    if not state.checkpoint then
        print("no checkpoint, assuming digging is finished, going home ...")
        Squirtle.navigate(state.home, nil, isBreakable)
        print("done & home <3")

        return
    end

    local position = Squirtle.locate()

    if not World.isInBounds(state.world, position) then
        print("not inside digging area, going there now...")
        -- [todo] goto start first instead (and then to checkpoint) - if digging area is further away the turtle might otherwise
        -- start making new tunnels to get to checkpoint
        Squirtle.navigate(state.start, nil, isBreakable)
        print("at start! going to checkpoint...")
        Squirtle.navigate(state.checkpoint, nil, isBreakable)
        print("should be inside digging area again!")
    end

    local point = state.checkpoint
    local previous = point
    local maxFailedNavigates = state.world.width * state.world.depth
    local numFailedNavigates = 0
    Squirtle.select(1)

    while point do
        if previous and previous.y ~= point.y then
            print("saving checkpoint at", point)
            state.checkpoint = point
            saveState(state)
        end

        local moved, msg = Squirtle.navigate(point, state.world, isBreakable)

        if not moved then
            numFailedNavigates = numFailedNavigates + 1
            print(msg, numFailedNavigates)

            -- [todo] for this to work reliably, we would need to save numFailedNavigates
            -- to disk after each step, which is not something i want to do
            if numFailedNavigates >= maxFailedNavigates then
                print("can't dig further, going home")
                Squirtle.navigate(state.home, nil, isBreakable)
                error("todo: implement 'blocked to dig further' case, which should allow for reprogramming minable blocks")
            end
        else
            numFailedNavigates = 0

            if isBreakable(Squirtle.probe("top")) then
                Squirtle.dig("up")
            end

            if isBreakable(Squirtle.probe("bottom")) then
                Squirtle.dig("down")
            end
        end

        previous = point
        point = nextPoint(point, state.world, state.start)

        local gettingFull = Squirtle.getStack(16) ~= nil
        local lowFuel = not Squirtle.hasFuel(1000)
        local minFuel = 1200
        local buffer = "top"

        if gettingFull or lowFuel then
            if gettingFull then
                print("getting full! going going home to dump inventory")
            elseif lowFuel then
                print("low on fuel! going home to get some")
            end

            print("saving checkpoint at", point)
            state.checkpoint = point
            saveState(state)
            Squirtle.navigate(state.home, nil, isBreakable)

            if args[1] == "io" then
                if not Squirtle.dump(buffer) then
                    error("buffer full")
                end
            else
                while not Squirtle.dump(buffer) do
                    print("chest full, sleeping 7s...")
                    os.sleep(7)
                end
            end

            if args[1] == "io" then
                local io = Inventory.findChest()

                Squirtle.pushAllOutput(buffer, io)

                while not Squirtle.hasFuel(minFuel) do
                    print("trying to refuel to ", minFuel, ", have", Squirtle.getFuelLevel())
                    Squirtle.pullInput(io, buffer)
                    refuelFromBuffer(buffer, minFuel)

                    if not Squirtle.hasFuel(minFuel) then
                        os.sleep(3)
                    end
                end
            end

            print("unloaded all and have enough fuel - back to work!")
            Squirtle.select(1)
            Squirtle.navigate(state.checkpoint, nil, isBreakable)
        end
    end

    print("all done! going home...")
    state.checkpoint = nil
    saveState(state)
    Squirtle.navigate(state.home)
    print("done & home <3")
end

rednet.open("right")

while true do
    local success, msg = pcall(function()
        main(arg)
    end)

    if success then
        break
    end

    print(msg)
    rednet.broadcast(msg, "error")
    os.sleep(30)
end
