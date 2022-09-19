package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local turn = require "squirtle.turn"
local boot = require "build-platform.boot"
local move = require "squirtle.move"
local place = require "squirtle.place"
local dig = require "squirtle.dig"
local inspect = require "squirtle.inspect"

---@class BuildPlatformAppState
---@field depth integer
---@field width integer
---@field direction "bottom"|"top"

---@param direction "bottom"|"top"
local function placeBlock(direction)
    if place(direction) or inspect(direction) then
        return true
    end

    local currentSlot = turtle.getSelectedSlot()

    for slot = 1, 16 do
        if slot ~= currentSlot and turtle.getItemCount(slot) > 0 then
            turtle.select(slot)

            if place(direction) then
                return true
            end
        end
    end

    return false
end

---@param args table<string>
---@return boolean
local function main(args)
    print("[build-platform v1.1.1] booting...")
    local state = boot(args)

    if not state then
        return false
    end

    local lineLength
    local numLines

    ---@param side string
    local function turnMove(side)
        turn(side)
        while not move("front") do
            dig("front")
        end
        turn(side)
    end

    ---@param currentLine integer
    local function moveToNextLine(currentLine)
        if state.width > state.depth then
            if currentLine % 2 == 0 then
                turnMove("right")
            else
                turnMove("left")
            end
        else
            if currentLine % 2 == 0 then
                turnMove("left")
            else
                turnMove("right")
            end
        end
    end

    if state.width > state.depth then
        turn("right")
        lineLength = state.width
        numLines = state.depth
    else
        lineLength = state.depth
        numLines = state.width
    end

    for line = 1, numLines do
        for _ = 1, lineLength do
            if not placeBlock(state.direction) then
                print("failed to place a block below me :(")
                print("fix the situation, then press any key")

                repeat
                    os.pullEvent("key")
                until placeBlock(state.direction)
            end

            if _ ~= lineLength then
                while not move("front") do
                    dig("front")
                end
            end
        end

        if line == numLines then
            break
        end

        moveToNextLine(line)
    end

    return true
end

return main(arg)
