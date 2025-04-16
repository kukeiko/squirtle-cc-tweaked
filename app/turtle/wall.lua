if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local EventLoop = require "lib.tools.event-loop"
local TurtleApi = require "lib.apis.turtle.turtle-api"

local function readPattern()
    ---@type string[]
    local pattern = {}

    for slot = 1, TurtleApi.size() do
        local stack = TurtleApi.getStack(slot)

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
    term.clear()
    term.setCursorPos(1, 1)

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

---@return "up" | "left" | "right"
local function promptExitDirection()
    term.clear()
    term.setCursorPos(1, 1)

    print("[prompt] towards which side of the wall is space for me to exit to so I can place the last block?")
    print(" (1) up")
    print(" (2) right")
    print(" (3) left")

    local directions = {"up", "right", "left"}
    return directions[EventLoop.pullInteger(1, 3)]
end

---@return boolean
local function promptShouldReturnHome()
    term.clear()
    term.setCursorPos(1, 1)

    print("[prompt] should I return home?")
    print(" (1) yes")
    print(" (2) no")

    local options = {true, false}
    return options[EventLoop.pullInteger(1, 2)]
end

---@return boolean
local function promptShouldDigArea()
    term.clear()
    term.setCursorPos(1, 1)

    print("[prompt] should I dig out the area first?")
    print(" (1) yes")
    print(" (2) no")

    local options = {true, false}
    return options[EventLoop.pullInteger(1, 2)]
end

---@param state WallAppState
local function sequence(state)
    TurtleApi.turn("back")
    local patternIndex = 1

    for line = 1, state.height do
        local item = state.pattern[((patternIndex - 1) % #state.pattern) + 1]

        for column = 1, state.depth do
            item = state.pattern[((patternIndex - 1) % #state.pattern) + 1]

            if column ~= state.depth then
                TurtleApi.move("back")
                TurtleApi.put("front", item)
            elseif line == state.height then
                -- last block: move based on configured exit direction
                if state.exitDirection == "up" then
                    TurtleApi.move("up")
                    TurtleApi.put("bottom", item)
                elseif state.exitDirection == "left" then
                    if line % 2 == 0 then
                        TurtleApi.turn("right")
                    else
                        TurtleApi.turn("left")
                    end

                    TurtleApi.move("back")
                    TurtleApi.put("front", item)
                elseif state.exitDirection == "right" then
                    if line % 2 == 0 then
                        TurtleApi.turn("left")
                    else
                        TurtleApi.turn("right")
                    end

                    TurtleApi.move("back")
                    TurtleApi.put("front", item)
                end

                -- exit out as we're finished with building the wall
                return
            else
                TurtleApi.move("up")
                TurtleApi.put("bottom", item)

                if line ~= state.height then
                    TurtleApi.turn("back")
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

EventLoop.run(function()
    ---@class WallAppState
    ---@field patternMode integer
    ---@field pattern string[]
    ---@field exitDirection "up" | "left" | "right"
    ---@field shouldReturnHome boolean
    ---@field shouldDigArea boolean
    local state = {depth = 0, height = 0, exitDirection = "up", shouldReturnHome = false, shouldDigArea = false}

    local function printUsage()
        print("Usage:")
        print("wall <depth> <height>")
    end

    term.clear()
    term.setCursorPos(1, 1)
    print(string.format("[wall %s] booting...", version()))
    local depth = tonumber(arg[1])
    local height = tonumber(arg[2])

    if not depth or not height or depth < 1 or height < 1 then
        return printUsage()
    end

    -- [todo] make this app resumable, however: in case of a crash, the player has to help the turtle orientate itself
    -- by providing a disk-drive and breaking a block at top or bottom for the turtle to place it.
    -- should use TurtleService to communicate that the turtle needs help from the player.
    state.patternMode = promptPatternMode()
    state.pattern = promptPattern(state.patternMode)
    state.exitDirection = promptExitDirection()
    state.shouldReturnHome = promptShouldReturnHome()
    state.shouldDigArea = promptShouldDigArea()
    state.depth = depth
    state.height = height
    TurtleApi.beginSimulation()
    sequence(state)
    local results = TurtleApi.endSimulation()
    TurtleApi.requireItems(results.placed)
    print("[ok] all good now! building...")
    local home = TurtleApi.getPosition()

    -- [todo] what delta to apply for exitDirection == "up"?
    if state.exitDirection == "left" then
        home = TurtleApi.getDeltaPosition("left")
    elseif state.exitDirection == "right" then
        home = TurtleApi.getDeltaPosition("right")
    end

    if state.shouldDigArea then
        -- [todo] when I make this app resumable, I should consider that digArea() is using navigate(), which is not simulation safe yet.
        -- either I make it simulation safe, or change digArea() to use simple way of moving back
        TurtleApi.digArea(state.depth, 1, state.height)
    end

    sequence(state)

    if state.shouldReturnHome then
        print("[home] going home!")
        TurtleApi.navigate(home)
    end

    print("[done]")
end)

