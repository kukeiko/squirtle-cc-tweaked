if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

package.path = package.path .. ";/app/turtle/?.lua"
local boot = require "build-platform.boot"
local TurtleApi = require "lib.apis.turtle.turtle-api"

---@class BuildPlatformAppState
---@field depth integer
---@field width integer
---@field direction "bottom"|"top"

---@param side "bottom"|"top"
local function placeBlock(side)
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            local item = turtle.getItemDetail(slot)

            if item.name ~= "minecraft:sand" and item.name ~= "minecraft:gravel" then
                turtle.select(slot)

                if TurtleApi.tryPut(side) then
                    return true
                end
            end
        end
    end

    return false
end

---@param args table<string>
---@return boolean
local function main(args)
    print(string.format("[build-platform %s] booting...", version()))
    local state = boot(args)

    if not state then
        return false
    end

    ---@param side string
    local function turnMove(side)
        TurtleApi.turn(side)
        TurtleApi.move()
        TurtleApi.turn(side)
    end

    ---@param currentLine integer
    local function moveToNextLine(currentLine)
        if currentLine % 2 == 1 then
            turnMove("right")
        else
            turnMove("left")
        end
    end

    for line = 1, state.width do
        for _ = 1, state.depth do
            if not placeBlock(state.direction) then
                print("failed to place a block below me :(")
                print("fix the situation, then press any key")

                repeat
                    os.pullEvent("key")
                until placeBlock(state.direction)
            end

            if _ ~= state.depth then
                TurtleApi.move()
            end
        end

        if line == state.width then
            break
        end

        moveToNextLine(line)
    end

    return true
end

return main(arg)
