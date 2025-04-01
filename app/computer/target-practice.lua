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
local maxScore = 10
local maxSimultaneousTargets = 2
local hitSide = Side.getName(Side.left)
local showTargetSide = Side.getName(Side.right)
local scoreSide = Side.getName(Side.right)

---@class TargetPracticeService : Service
local TargetPracticeService = {name = "target-practice", maxDistance = 128}

---@param duration number
---@return boolean hit
function TargetPracticeService.showTarget(duration)
    local hit = EventLoop.runUntil("target-practice:hit", function()
        redstone.setOutput(showTargetSide, true)
        os.sleep(1)
        redstone.setOutput(showTargetSide, false)
        os.sleep(duration)
        redstone.setOutput(showTargetSide, true)
        os.sleep(1)
        redstone.setOutput(showTargetSide, false)
    end)

    if hit then
        redstone.setOutput(showTargetSide, true)
        os.sleep(1)
        redstone.setOutput(showTargetSide, false)
    end

    return hit
end

local function server()
    Utils.writeStartupFile("target-practice")

    EventLoop.run(function()
        RemoteService.run({"target-practice"})
    end, function()
        Rpc.host(TargetPracticeService)
    end, function()
        while true do
            EventLoop.pull("redstone")

            if redstone.getInput(hitSide) then
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

local function game()
    local score = 0
    local timeBetweenTargets = 5
    local timeShowTargets = 5

    ---@param nextScore integer
    local function setScore(nextScore)
        score = math.max(0, math.min(nextScore, maxScore))
        print("[score]", score)
        redstone.setAnalogOutput(scoreSide, score)
    end

    setScore(0)

    local targets = Rpc.all(TargetPracticeService)

    if #targets < maxSimultaneousTargets * 2 then
        error(string.format("not enough targets, found %d/%d", #targets, maxSimultaneousTargets * 2))
    end

    ---@type (TargetPracticeService|RpcClient)[]
    local previousTargets = {}

    while score < maxScore do
        os.sleep(timeBetweenTargets)

        ---@type (TargetPracticeService|RpcClient)[]
        local nextTargets = pickTargets(targets, previousTargets, maxSimultaneousTargets)

        EventLoop.run(table.unpack(Utils.map(nextTargets, function(target)
            return function()
                if target.showTarget(timeShowTargets) then
                    setScore(score + 1)
                    print("[hit]", target.host)
                else
                    setScore(score - 1)
                    print("[miss]", target.host)
                end
            end
        end)))

        previousTargets = nextTargets
    end

    print("[success] the players won!")
end

local function client()
    Utils.writeStartupFile("target-practice client")

    EventLoop.run(function()
        RemoteService.run({"target-practice"})
    end, function()
        -- [todo] should wait for player input to start the game so that all targets are in range
        os.sleep(3) -- give targets enough time to boot

        while true do
            game()
        end
    end)
end

EventLoop.run(function()
    if isClient then
        client()
    else
        server()
    end
end)
