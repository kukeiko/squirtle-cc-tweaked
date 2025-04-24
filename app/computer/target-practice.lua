if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local Side = require "lib.apis.side"
local RemoteService = require "lib.systems.runtime.remote-service"
local isClient = arg[1] == "client"
local score = 0
local maxScore = 10
local hitSide = Side.getName(Side.left)
local showTargetSide = Side.getName(Side.right)
local scoreSide = Side.getName(Side.right)

local cooldowns = {
    {5, 5, 5, 5, 4, 4, 4, 3, 3, 3}, -- easy
    {5, 4, 3, 3, 2, 2, 1, 1, 0, 0}, -- medium
    {3, 2, 1, 1, 1, 0, 0, 0, 0, 0} -- hard
}
local durations = {
    {5, 5, 5, 5, 4, 4, 4, 3, 3, 3}, -- easy
    {5, 4, 3, 3, 2, 2, 1, 1, 1, 1}, -- medium
    {2, 2, 2, 1, 1, 1, 1, 1, 1, 1} -- hard
}

-- [todo] move service to lib.systems.games
---@class TargetPracticeService : Service
local TargetPracticeService = {name = "target-practice", maxDistance = 128}
local isTogglingTarget = false

local function toggleShowTarget()
    isTogglingTarget = true
    redstone.setOutput(showTargetSide, true)
    os.sleep(1)
    redstone.setOutput(showTargetSide, false)
    os.sleep(1)
    isTogglingTarget = false
end

---@param duration number
---@return boolean hit
function TargetPracticeService.showTarget(duration)
    local hit = EventLoop.runUntil("target-practice:hit", function()
        toggleShowTarget()
        os.sleep(duration)
        toggleShowTarget()
    end)

    if hit then
        toggleShowTarget()
    end

    return hit
end

local function server()
    Utils.writeStartupFile("target-practice")

    EventLoop.run(function()
        Rpc.host(TargetPracticeService)
    end, function()
        while true do
            EventLoop.pull("redstone")

            if redstone.getInput(hitSide) then
                while isTogglingTarget do
                    os.sleep(.1)
                end

                print("[hit]", redstone.getAnalogInput(hitSide))
                EventLoop.queue("target-practice:hit")
                os.sleep(1) -- to debounce observer input and multiple hits
            end
        end
    end)
end

---@param targets (TargetPracticeService|RpcClient)[]
---@param previousTargets (TargetPracticeService|RpcClient)[]
---@param maxSimultaneousTargets integer
---@return (TargetPracticeService|RpcClient)[]
local function pickTargets(targets, previousTargets, maxSimultaneousTargets)
    ---@type (TargetPracticeService|RpcClient)[]
    local nextTargets = {}

    for _ = 1, maxSimultaneousTargets do
        ---@type (TargetPracticeService|RpcClient)?
        local candidate = nil

        while not candidate do
            candidate = targets[math.random(#targets)]

            if Utils.indexOf(previousTargets, candidate) or Utils.indexOf(nextTargets, candidate) then
                candidate = nil
            end
        end

        table.insert(nextTargets, candidate)
    end

    return nextTargets
end

local function showWonAnimation()
    for _ = 1, 3 do
        redstone.setOutput(scoreSide, false)
        os.sleep(.5)
        redstone.setOutput(scoreSide, true)
        os.sleep(.5)
    end
end

---@param nextScore integer
local function setScore(nextScore)
    score = math.max(0, math.min(nextScore, maxScore))
    print("[score]", score)
    redstone.setAnalogOutput(scoreSide, score)
end

---@param playerCount integer
---@param difficulty integer
local function game(playerCount, difficulty)
    local speaker = peripheral.find("speaker")
    setScore(0)

    local targets = Rpc.all(TargetPracticeService)

    if #targets < playerCount * 2 then
        error(string.format("not enough targets, found %d/%d", #targets, playerCount * 2))
    end

    ---@type (TargetPracticeService|RpcClient)[]
    local previousTargets = {}

    while score < maxScore do
        local cooldown = cooldowns[difficulty][score + 1]
        local duration = durations[difficulty][score + 1]
        print(string.format("[cooldown] %ds", cooldown))
        os.sleep(cooldown)
        local nextTargets = pickTargets(targets, previousTargets, playerCount)
        print(string.format("[duration] %ds", duration))

        local hitCount = 0
        EventLoop.run(table.unpack(Utils.map(nextTargets, function(target)
            return function()
                if target.showTarget(duration) then
                    hitCount = hitCount + 1
                    print("[hit]", target.host)
                else
                    hitCount = hitCount - 1
                    print("[miss]", target.host)
                end
            end
        end)))

        if hitCount == playerCount then
            setScore(score + 1)

            if speaker then
                if score < maxScore then
                    speaker.playSound("entity.player.levelup", 3)
                end
            end
        else
            setScore(score - 1)

            if speaker then
                speaker.playSound("block.lava.extinguish", 3)
            end
        end

        previousTargets = nextTargets
    end

    speaker.playSound("ui.toast.challenge_complete", 3)
    setScore(maxScore)
    os.sleep(.5)
    print("[success] the players won!")
    showWonAnimation()
    redstone.setOutput("bottom", true)
end

local function testAllTargets()
    local targets = Rpc.all(TargetPracticeService)
    EventLoop.run(table.unpack(Utils.map(targets, function(target)
        return function()
            target.showTarget(3)
        end
    end)))
end

local function client()
    Utils.writeStartupFile("target-practice client")
    setScore(0)

    while true do
        redstone.setOutput("bottom", false)
        print("[prompt] how many players?")
        local playerCount = EventLoop.pullInteger(0, 4)

        if playerCount == 0 then
            print("[test] all targets")
            testAllTargets()
        else
            print("[players]", playerCount)
            print("[prompt] what difficulty?")
            print(" (1) easy")
            print(" (2) medium")
            print(" (3) hard")
            local difficulty = EventLoop.pullInteger(1, 3)
            print("[start] get ready!")
            game(playerCount, difficulty)
            Utils.waitForUserToHitEnter("(hit enter to close door and restart)")
        end
    end
end

EventLoop.run(function()
    RemoteService.run({"target-practice"})
end, function()
    if isClient then
        client()
    else
        server()
    end
end)
