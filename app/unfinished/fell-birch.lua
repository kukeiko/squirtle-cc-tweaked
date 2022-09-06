package.path = package.path .. ";/?.lua"

--[[
    this program is incomplete as i didn't manage to figure out how to climb down the tree
    after climbing it. i mean i have some ideas, but i wasn't happy with any of them.
    after a bit of thinking i decided to instead go with a tree farm that waits for the
    leafs to naturally decay, and goodies dropped are collected via water. app: lumberjack
]]

local Backpack = require "squirtle.backpack"
local inspect = require "squirtle.inspect"
local Side = require "elements.side"
local turn = require "squirtle.turn"
local dig = require "squirtle.dig"
local move = require "squirtle.move"

---@class TheState
---@field front? Block
---@field bottom? Block
---@field top? Block
---@field bits number

local myBits = {leafLoop = 1, leafLoopEntered = 2, steppingOut = 4, climbing = 8}

local function hasBits(subject, bits)
    return bit.band(subject, bits) == bits
end

local function readState()
    ---@type TheState
    local state = {
        front = inspect(Side.front),
        bottom = inspect(Side.bottom),
        top = inspect(Side.top),
        bits = Backpack.readBits()
    }

    return state
end

local function suspend()
    -- os.sleep(1)
    -- print("[press enter to continue]")
    -- Utils.waitForUserToHitEnter()
end

local function main(args)
    Backpack.setBits(myBits.climbing)

    while true do
        local state = readState()
        local lookingAtLog = state.front and state.front.tags["minecraft:logs"]
        local lookingAtPlanks = state.front and state.front.tags["minecraft:planks"]
        local lookingAtLeafs = state.front and state.front.tags["minecraft:leaves"]
        local isLeafLoop = hasBits(state.bits, myBits.leafLoop)
        local enteredLeafLoop = hasBits(state.bits, myBits.leafLoopEntered)
        local isSteppingOut = hasBits(state.bits, myBits.steppingOut)
        local isClimbing = hasBits(state.bits, myBits.climbing)
        local bottomIsLog = state.bottom and state.bottom.tags["minecraft:logs"]

        if lookingAtLog then
            if not isLeafLoop and not isSteppingOut then
                print("begin 1st leaf loop")
                Backpack.orBits(myBits.leafLoop)
            elseif isLeafLoop and not enteredLeafLoop then
                print("1st loop turn")
                turn(Side.left)
            elseif isLeafLoop and enteredLeafLoop then
                print("leafs cut! set bits for stepping out...")
                local bitsWithoutLeafLoop = bit.bxor(state.bits, bit.bor(myBits.leafLoop, myBits.leafLoopEntered))
                local nextBits = bit.bor(myBits.steppingOut, bitsWithoutLeafLoop)
                Backpack.setBits(nextBits)
            elseif not isLeafLoop and not enteredLeafLoop and isSteppingOut then
                print("stepping out!")
                -- [todo] assert existance of planks block
                move(Side.back)
            elseif not isLeafLoop and enteredLeafLoop and isSteppingOut then
                -- settings bits first so that in case of a crash, we do not skip cutting leafs of the current layer
                Backpack.setBits(bit.bxor(state.bits, bit.bor(myBits.leafLoopEntered, myBits.steppingOut)))

                if isClimbing then
                    print("stepped back! going up...")
                    dig(Side.top)
                    move(Side.top)
                else
                    print("stepped back! going down...")
                    dig(Side.bottom)
                    move(Side.bottom)
                end
            else
                error("unknown state")
            end
        elseif isLeafLoop and (lookingAtLeafs or not state.front) then
            if not enteredLeafLoop then
                print("1st turn done (entered leaf loop)")
                Backpack.orBits(myBits.leafLoopEntered)
            end

            if lookingAtLeafs then
                print("cutting leafs, then turning left")
                dig()
            else
                print("no leafs to cut, turning left")
            end

            turn(Side.left)
        elseif lookingAtLeafs then
            print("found leafs while not in leaf loop, cutting them...")
            dig()
        elseif not state.front then
            if isSteppingOut and not isLeafLoop and not enteredLeafLoop then
                -- [todo] support any type of planks
                local slot = Backpack.selectItem("minecraft:birch_planks")

                if not slot then
                    error("no planks found")
                end

                print("stepped out, placing planks")
                -- [todo] use squirtle
                turtle.place()
            elseif isSteppingOut and not isLeafLoop and enteredLeafLoop then
                print("stepping back by moving forwards...")
                move()
            elseif not isSteppingOut and not isLeafLoop and not enteredLeafLoop and isClimbing and not bottomIsLog then
                print("reached the top! going forward...")
                move()
            elseif bottomIsLog then
                print("sitting on top! climbing = false...")
                Backpack.xorBits(myBits.climbing)
                print("... and moving forward")
                move()
                dig(Side.bottom)
                move(Side.bottom)
                turn(Side.back)
                -- else
            else
                error("unknown state")
            end
        elseif lookingAtPlanks then
            if not isLeafLoop and not enteredLeafLoop then
                print("begin 2nd leaf loop")
                Backpack.orBits(myBits.leafLoop)
            elseif isLeafLoop and not enteredLeafLoop then
                print("1st loop turn")
                turn(Side.left)
            elseif isLeafLoop and enteredLeafLoop then
                print("leafs cut! set bits for stepping back...")
                Backpack.setBits(bit.bxor(state.bits, myBits.leafLoop))
            elseif not isLeafLoop and enteredLeafLoop then
                print("begin stepping back, digging planks...")
                dig()
            else
                error("unknown state")
            end
        end

        suspend()
    end
end

main(arg)
