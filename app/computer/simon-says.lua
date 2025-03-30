if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local Utils = require "lib.tools.utils"
local isClient = arg[1] == "client"
local requiredPlayers = 1

if not isClient then
    requiredPlayers = tonumber(arg[1]) or 1
end

local sounds = {front = "entity.pig.ambient", back = "entity.cow.ambient", left = "entity.chicken.ambient", right = "entity.sheep.ambient"}

---@class SimonSaysService : Service
local SimonSaysService = {name = "simon-says"}
local playedSounds = {}
local activePlayers = 0
local score = 0
local maxScore = 10
local responseTime = 3

function SimonSaysService.playerStarted()
    activePlayers = math.min(requiredPlayers, activePlayers + 1)
    print(string.format("[player] started, active: %d/%d", activePlayers, requiredPlayers))

    if activePlayers == requiredPlayers then
        EventLoop.queue("simon-says:start")
    end
end

function SimonSaysService.playerExited()
    activePlayers = math.max(0, activePlayers - 1)
    print(string.format("[player] exited, active: %d/%d", activePlayers, requiredPlayers))
    EventLoop.queue("simon-says:stop")
end

function SimonSaysService.playedSound(sound)
    table.insert(playedSounds, sound)

    if #playedSounds == requiredPlayers then
        EventLoop.queue("simon-says:all-played")
    end
end

local speaker = peripheral.find("speaker")

if not speaker then
    error("no speaker found")
end

local function client()
    local service = Rpc.nearest(SimonSaysService)
    local isPlaying = false

    while true do
        EventLoop.pull("redstone")

        if redstone.getInput("top") and not isPlaying then
            service.playerStarted()
            isPlaying = true
        elseif not redstone.getInput("top") then
            service.playerExited()
            isPlaying = false
        end

        if isPlaying then
            for side, sound in pairs(sounds) do
                if redstone.getInput(side) then
                    speaker.playSound(sound, 3)
                    service.playedSound(sound)
                    break
                end
            end
        end
    end
end

---@param nextScore integer
local function setScore(nextScore)
    score = nextScore
    print("[score]", score)
    redstone.setAnalogOutput("right", score)
end

local function game()
    while score < maxScore do
        local sounds = Utils.toList(sounds)
        local rnd = math.random(#sounds)
        speaker.playSound(sounds[rnd], 3)

        EventLoop.runTimed(responseTime, function()
            EventLoop.pull("simon-says:all-played")
        end)

        if #playedSounds == requiredPlayers and Utils.every(playedSounds, function(item)
            return item == sounds[rnd]
        end) then
            setScore(score + 1)
        else
            setScore(0)
        end

        os.sleep(3)
        playedSounds = {}
    end
end

local function abort()
    setScore(0)
end

local function win()
    print("[success] good job!")
end

local function server()
    term.redirect(peripheral.find("monitor"))

    EventLoop.run(function()
        Rpc.host(SimonSaysService)
    end, function()
        while true do
            EventLoop.pull("simon-says:start")
            setScore(0)
            if EventLoop.runUntil("simon-says:stop", game) then
                abort()
            else
                win()
            end
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
