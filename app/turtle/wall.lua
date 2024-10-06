package.path = package.path .. ";/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Squirtle = require "lib.squirtle.squirtle-api"
local SquirtleState = require "lib.squirtle.state"
local readInteger = require "lib.ui.read-integer"

local function readPattern()
    ---@type string[]
    local pattern = {}

    for slot = 1, Squirtle.size() do
        local stack = Squirtle.getStack(slot)

        if stack then
            for _ = 1, stack.count do
                table.insert(pattern, stack.name)
            end
        end
    end

    return pattern
end

---@return integer
local function promptPatternMode()
    print("[prompt] choose pattern mode by entering number")
    print(" (1) alternate block")
    print(" (2) alternate layer")
    ---@type integer|nil
    local mode = 0

    while not mode or mode < 1 or mode > 2 do
        mode = readInteger(1, {})
    end

    return mode
end

local function promptPattern()
    print("[prompt] put block pattern into inventory, then confirm with enter")

    while true do
        local _, key = os.pullEvent("key")

        if key == keys.enter then
            local pattern = readPattern()

            if #pattern > 0 then
                return pattern
            end

            print("[error] no blocks in inventory")
        end
    end
end

---@param state WallAppState
local function sequence(state)
    Squirtle.turn("back")
    local patternIndex = 1

    for line = 1, state.height do
        local item = state.pattern[((patternIndex - 1) % #state.pattern) + 1]

        for column = 1, state.depth do
            item = state.pattern[((patternIndex - 1) % #state.pattern) + 1]

            if column ~= state.depth then
                Squirtle.move("back")
                Squirtle.put("front", item)
            elseif line == state.height then
                -- exit out without placing the last block so the turtle is easier to find for the player to pick up again
                return
            else
                Squirtle.move("up")
                Squirtle.put("bottom", item)

                if line ~= state.height then
                    Squirtle.turn("back")
                end
            end

            if state.patternMode == 1 then
                patternIndex = patternIndex + 1
            end
        end

        if state.patternMode == 2 then
            patternIndex = patternIndex + 1
        end
    end
end

---@class WallAppState
---@field patternMode integer
---@field pattern string[]
local state = {depth = 0, height = 0}

local function printUsage()
    print("Usage:")
    print("wall <depth> <height>")
end

print("[wall v2.0.0] booting...")
local depth = tonumber(arg[1])
local height = tonumber(arg[2])

if not depth or not height or depth < 1 or height < 1 then
    return printUsage()
end

state.patternMode = promptPatternMode()
state.pattern = promptPattern()
state.depth = depth
state.height = height
SquirtleState.simulate = true
sequence(state)
SquirtleState.simulate = false
Squirtle.requireItems(SquirtleState.results.placed)
print("[ok] all good now! building...")
sequence(state)
