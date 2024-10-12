package.path = package.path .. ";/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local EventLoop = require "lib.common.event-loop"
local Squirtle = require "lib.squirtle.squirtle-api"
local SquirtleState = require "lib.squirtle.state"

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
    print("[prompt] choose pattern mode:")
    print(" (1) alternate block")
    print(" (2) alternate layer")

    return EventLoop.pullInteger(1, 2)
end

---@param patternMode integer
---@return string[]
local function promptPattern(patternMode)
    term.clear()
    term.setCursorPos(1, 1)

    if patternMode == 1 then
        print("[prompt] put block pattern into inventory, then confirm with enter.")
        print(" - stack size determines how often that block will be repeated")
        print(" - place blocks row-wise - i.e. first block in slot #1, second in slot #2 and so on")
        print("")
        print(
            "[example] 1x stone bricks in slot #1, 2x stone in slot #2 will place 1x stone bricks and then 2x stones - repeating this pattern")
    else
        print("[prompt] put layer pattern into inventory, then confirm with enter.")
        print(" - stack size determines how many layers of that block will be placed")
        print(" - place blocks row-wise - i.e. first block in slot #1, second in slot #2 and so on")
        print("")
        print(
            "[example] 1x stone bricks in slot #1, 2x stone in slot #2 will place 1x layer of stone bricks and then 2x layers of stones - repeating this pattern")

    end

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

term.clear()
term.setCursorPos(1, 1)
print("[wall v2.1.0-dev] booting...")
local depth = tonumber(arg[1])
local height = tonumber(arg[2])

if not depth or not height or depth < 1 or height < 1 then
    return printUsage()
end

state.patternMode = promptPatternMode()
state.pattern = promptPattern(state.patternMode)
state.depth = depth
state.height = height
SquirtleState.simulate = true
sequence(state)
SquirtleState.simulate = false
Squirtle.requireItems(SquirtleState.results.placed)
print("[ok] all good now! building...")
sequence(state)
print("[done]")
