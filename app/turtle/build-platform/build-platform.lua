package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local turn = require "squirtle.turn"
local boot = require "build-platform.boot"
local move = require "squirtle.move"
local place = require "squirtle.place"

---@class BuildPlatformAppState
---@field depth integer
---@field width integer

local function placeBlock()
    if not place("bottom") then
        if turtle.getItemCount() > 0 then
            -- assuming a block is already there
            return true
        end

        for slot = 1, 16 do
            if turtle.getItemCount(slot) > 0 then
                turtle.select(slot)

                if not place("bottom") then
                    -- assume a block magically appeared since last check
                    return true
                end
            end
        end

        return false
    end

    return true
end

---@param args table<string>
---@return boolean
local function main(args)
    print("[build-platform v1.0.0] booting...")
    local state = boot(args)

    if not state then
        return false
    end

    local lineLength
    local numLines

    ---@param side string
    local function turnMove(side)
        turn(side)
        if not move("front") then
            error("failed to move forward")
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
            if not placeBlock() then
                error("failed to place a block below me :(")
            end

            if _ ~= lineLength then
                if not move("front") then
                    error("failed to move forward")
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
