package.path = package.path .. ";/libs/?.lua"

local Home = require "home"
local Container = require "container"
local Inventory = require "inventory"
local Logger = require "logger"
local Peripheral = require "peripheral"
local Refueler = require "refueler"
local Sides = require "sides"
local Squirtle = require "squirtle"
local Turtle = require "turtle"
local Utils = require "utils"
local Workspace = require "workspace"

local function parseInputSide(argInputSide)
    if argInputSide == "from-bottom" then
        return "bottom"
    elseif argInputSide == "from-top" then
        return "top"
    else
        error("invalid input side: " .. argInputSide)
    end
end

local function parseOptions(args)
    local options = {autorun = false, reset = false}

    for i = 1, #args do
        if options[args[i]] ~= nil then
            options[args[i]] = true
        end
    end

    return options
end

local function dropIntoStorageChest(side)
    local filterChest = peripheral.wrap(side)
    local numItemTypes = 0
    local itemsToDrop = {}
    local slotsToDrop = {}

    for _, filteredItem in pairs(filterChest.list()) do
        if not itemsToDrop[filteredItem.name] then
            numItemTypes = numItemTypes + 1
        end

        itemsToDrop[filteredItem.name] = true
    end

    for slot = 1, Inventory.size() do
        local candidate = turtle.getItemDetail(slot)

        if candidate ~= nil and itemsToDrop[candidate.name] then
            table.insert(slotsToDrop, slot)
        end
    end

    if (#slotsToDrop > 0) then
        local dropSide, undoFaceStorage = Turtle.faceSide(side)

        -- [todo]: break early if chest is full. need to be careful about chests that
        -- have more than one item type to sort in.
        for i = 1, #slotsToDrop do
            turtle.select(slotsToDrop[i])

            if not Turtle.drop(dropSide) and numItemTypes == 1 then
                -- we can break early because chest only accepts 1 type of item, so a failure in
                -- dropping items can only be because the chest is full
                break
            end
        end

        undoFaceStorage()
    end

    turtle.select(1)
end

local function distribute()
    local modemSide = Squirtle.findSideOfWirelessModem()
    local outputSide = Sides.invert(modemSide)

    while not Inventory.isEmpty() and turtle.forward() do
        if Peripheral.isContainerPresent(outputSide) then
            dropIntoStorageChest(outputSide)
        end
    end

    -- go home
    Turtle.turn(modemSide)
    Turtle.turn(modemSide)
    Turtle.forwardUntilBlocked()
    Turtle.turnAround()
end

local function findHome()
    local containers = Squirtle.wrapLocalContainers()
    -- [todo] check peripherals. we want to later make use of the crafting table, which could be equipped (possibly together with a modem)
    local modemSide = Squirtle.findSideOfWirelessModem()

    if not modemSide then
        -- [todo] implement Squirtle.requireWirelessModem(side)
        error("no wireless modem equipped")
    end

    if not containers.top or not containers.bottom then
        Logger.log("turned off while not at home, trying to find it...")
        Logger.debug("trying to infer the state i was in...")

        if containers.front then
            -- we were just unloading stuff
            Logger.debug("i was unloading items into a chest")
            dropIntoStorageChest("front")
            Turtle.turn(modemSide)
            distribute()
        elseif containers.back then
            -- we were just in the middle of turning back home
            Logger.debug("i was just turning towards home")
            Turtle.turn(modemSide)
            Turtle.forwardUntilBlocked()
        elseif containers.left then
            -- if modem is on the left, we were heading home. otherwise we were distributing.
            if modemSide == "left" then
                Logger.debug("i was heading home")
                Turtle.forwardUntilBlocked()
            else
                Logger.debug("i was distributing")
                distribute()
            end
        elseif containers.right then
            -- if modem is on the left, we were distributing. otherwise we were heading home.
            if modemSide == "left" then
                Logger.debug("i was distributing")
                distribute()
            else
                Logger.debug("i was heading home")
                Turtle.forwardUntilBlocked()
            end
        else
            -- we are either distributing or heading home.
            Logger.debug("i was either distributing or heading home")

            while Turtle.forward() do
                containers = Squirtle.wrapLocalContainers()

                if containers.left then
                    -- if modem is on the left, we were heading home. otherwise we were distributing.
                    if modemSide == "left" then
                        Logger.debug("i was heading home")
                        Turtle.forwardUntilBlocked()
                    else
                        Logger.debug("i was distributing")
                        distribute()
                    end
                    break
                elseif containers.right then
                    -- if modem is on the left, we were distributing. otherwise we were heading home.
                    if modemSide == "left" then
                        Logger.debug("i was distributing")
                        distribute()
                    else
                        Logger.debug("i was heading home")
                        Turtle.forwardUntilBlocked()
                    end
                    break
                end
            end
        end

        containers = Squirtle.wrapLocalContainers()
    end

    -- [todo] recovery code is kinda stable, but optimizations are missing, like emptying out inventory to output
    -- (since via recovery we should've distributed as expected)

    local bufferSide

    for _, side in pairs(Sides.horizontal()) do
        if containers[side] and Peripheral.getType(containers[side]) == "minecraft:barrel" then
            bufferSide = side
            break
        end
    end

    if not bufferSide then
        error("no barrel (to use as a buffer) found :(")
    end

    Turtle.turnToHaveSideAt(bufferSide, "back")

    return Home.new(Turtle.inspectName("bottom"), "bottom", "minecraft:barrel", "back")
end

local function main(args)
    print("[storage-sorter @ 5.0.0]")
    -- todo: consolidate parsing into 1 method
    local argInputSide = args[1]
    local inputSide = parseInputSide(argInputSide)
    -- local outputSide = Sides.invert(inputSide)

    local options = parseOptions(args)

    if options.autorun then
        Utils.writeAutorunFile({"storage-sorter", argInputSide})
    end

    -- local home = findHome()
    findHome()
    local workspace = Workspace.create()
    workspace.input = {side = inputSide}
    workspace.buffer = {side = "back"}
    workspace.output = {side = Sides.invert(inputSide)}

    local fuelPerTrip = 200

    while true do
        local minFuel = fuelPerTrip * 2
        Squirtle.printFuelLevelToMonitor(minFuel)
        Refueler.requireFuelLevel(workspace, minFuel)
        Squirtle.printFuelLevelToMonitor(minFuel)

        if Turtle.getMissingFuel() > 0 then
            Refueler.refuel(workspace)
            Squirtle.printFuelLevelToMonitor(minFuel)
        end

        Refueler.passFuelToOutput(workspace)

        local input = Peripheral.wrap(workspace.input.side)

        for slot in pairs(input.list()) do
            if input.pushItems(workspace.buffer.side, slot) == 0 then
                break
            end
        end

        local buffer = Peripheral.wrap(workspace.buffer.side)

        if Container.countItems(buffer.list()) > 0 then
            Turtle.suckAll(workspace.buffer.side)
        end

        if not Inventory.isEmpty() then
            Logger.log("distributing...")
            local fuelBeforeTrip = Turtle.getFuelLevel()
            distribute()
            fuelPerTrip = fuelBeforeTrip - Turtle.getFuelLevel()
            Logger.log("dumping to output...")
            while not Inventory.dumpTo(workspace.output.side) do
                os.sleep(7)
            end
            Logger.log("checking input...")
        else
            os.sleep(3)
        end
    end
end

main(arg)
