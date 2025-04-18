if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local ItemApi = require "lib.apis.item-api"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local TurtleService = require "lib.systems.turtle-service"

local function readPattern()
    ---@type string[]
    local pattern = {}

    for slot = 1, TurtleApi.size() do
        local stack = TurtleApi.getStack(slot)

        if stack and stack.name ~= ItemApi.shulkerBox then
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
    print(" (2) left")
    print(" (3) right")

    local directions = {"up", "left", "right"}
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
    if not state.shouldDigArea then
        -- only turn if we didn't dig, as the return to home from digging caused us to already have the correct facing
        TurtleApi.turn("back")
    end

    local patternIndex = 1

    for line = 1, state.height do
        local item = state.pattern[((patternIndex - 1) % #state.pattern) + 1]

        for column = 1, state.depth do
            item = state.pattern[((patternIndex - 1) % #state.pattern) + 1]

            if column ~= state.depth then
                if not (state.shouldDigArea and line == 1 and column == 1) then
                    -- skip one step if we dug out the area as it positioned us to already be 1 step ahead 
                    TurtleApi.move("back")
                end

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

---@param args string[]
---@param options TurtleResumableOptions
---@return WallAppState?
local function start(args, options)
    ---@class WallAppState
    ---@field patternMode integer
    ---@field pattern string[]
    ---@field exitDirection "up" | "left" | "right"
    ---@field shouldReturnHome boolean
    ---@field shouldDigArea boolean
    ---@field home Vector
    ---@field facing integer
    local state = {
        depth = 0,
        height = 0,
        exitDirection = "up",
        shouldReturnHome = false,
        shouldDigArea = false,
        home = TurtleApi.getPosition(),
        facing = TurtleApi.getFacing()
    }

    local function printUsage()
        print("Usage:")
        print("wall <depth> <height>")
    end

    local depth = tonumber(args[1])
    local height = tonumber(args[2])

    if not depth or not height or depth < 1 or height < 1 then
        return printUsage()
    end

    state.patternMode = promptPatternMode()
    state.pattern = promptPattern(state.patternMode)
    state.exitDirection = promptExitDirection()

    if state.exitDirection ~= "up" then
        state.shouldReturnHome = promptShouldReturnHome()
    end

    if promptShouldDigArea() then
        state.shouldDigArea = true
        options.requireShulkers = true
    end

    state.depth = depth
    state.height = height

    if state.exitDirection == "left" then
        state.home = TurtleApi.getPositionTowards("left")
    elseif state.exitDirection == "right" then
        state.home = TurtleApi.getPositionTowards("right")
    end

    print("[ok] all good now! building...")

    return state
end

---@param state WallAppState
local function main(state)
    if state.shouldDigArea then
        -- adjusting home position/facing to optimize a bit - also it looks much better!
        TurtleApi.digArea(state.depth, 1, state.height, TurtleApi.getPositionTowards("forward"), TurtleApi.getFacingTowards("back"))
    end

    sequence(state)
end

---@param state WallAppState
local function resume(state)
    term.clear()
    term.setCursorPos(1, 1)
    print("[help] I got unloaded while digging out the area or building the wall.\n")
    print("Which direction relative to the direction I looked at when starting am I facing?\n")
    print(" (1) forward")
    print(" (2) left")
    print(" (3) right")
    print(" (4) back")

    local directions = {"forward", "left", "right", "back"}
    local choice = directions[EventLoop.pullInteger(1, 4)]
    TurtleApi.setFacing(state.facing)
    TurtleApi.setFacing(TurtleApi.getFacingTowards(choice))
end

---@param state WallAppState
local function finish(state)
    if state.shouldReturnHome then
        print("[home] going home!")
        TurtleApi.navigate(state.home)
        TurtleApi.face(state.facing)
    end

    print("[done] I hope you like what I built!")
end

print(string.format("[wall %s] booting...", version()))

EventLoop.run(function()
    EventLoop.runUntil("wall:stop", function()
        Rpc.host(TurtleService)
    end)
end, function()
    local success, message = TurtleApi.runResumable("app/turtle/wall", arg, start, main, resume, finish)

    if success then
        EventLoop.queue("wall:stop")
    else
        print(message)
        TurtleService.error = message
    end
end)

