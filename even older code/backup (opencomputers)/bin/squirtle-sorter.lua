-- 0.1.0
local robot = require("squirtle-robot") -- 0.1.0
local inventory = require("squirtle-robot-inventory") -- 0.1.0
local sides = require("squirtle-sides") -- 0.1.0

local homeSide = robot.getFacing()

function start()
    while true do
        waitForLoot()
        loot()
        distribute()
    end    
end

function log(msg)
    print(os.date("[%H:%M] "..msg))
end

function waitForLoot()
    log("waiting for loot")

    while not robot.suck() do
        if inventory.isFull() then
            log("inventory unexpectedly full")
            return nil
        end

        os.sleep(3)
    end

    log("found loot")
end

function loot()
    log("looting")

    while true do
        while robot.suck() do end

        if inventory.isFull() then
            log("inventory full")
            return nil
        else
            log("waiting 3s for more loot")
            os.sleep(3)

            if not robot.suck() then
                log("looting complete")
                return nil
            end
        end
    end
end

function distribute()
    log("distributing loot")

    repeat
        if not dropIntoChests() then
            break
        end

        if not moveToNextChests() then
            break
        end
    until false

    inventory.dump()

    log("distributed loot, going home")

    robot.turnTo(homeSide)
    while robot.forward() do end
end

function dropIntoChests()
    robot.turnRight()
    dropIntoChest()

    if(inventory.isEmpty()) then return false end

    robot.turnAround()
    dropIntoChest()

    return not inventory.isEmpty()
end

function dropIntoChest()
    local passable, type = robot.detect()
    
    if type ~= "solid" then
        return nil
    end

    local droppableSlots = {}

    for i = 1, robot.inventorySize() do
        if robot.count(i) > 0 then
            robot.select(i)
            
            if robot.compare() then
                table.insert(droppableSlots, i)
            end
        end
    end

    if #droppableSlots > 0 then
        robot.up()

        for i = 1, #droppableSlots do
            robot.select(droppableSlots[i])
            robot.drop()
        end

        robot.down()
    end
end

function moveToNextChests()
    robot.turnTo(sides.turn.around[homeSide])

    if not robot.forward(2) then
        return false
    end

    return true
end

start()
