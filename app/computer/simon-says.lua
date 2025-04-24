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
local RemoteService = require "lib.systems.runtime.remote-service"
local isClient = arg[1] == "client"
local sounds = {front = "entity.pig.ambient", back = "entity.cow.ambient", left = "entity.chicken.ambient", right = "entity.sheep.ambient"}

-- [todo] move service to lib.systems.games
---@class SimonSaysService : Service
local SimonSaysService = {name = "simon-says"}
local playedSounds = {}
local activePlayers = 0
local requiredPlayers = 1
local score = 0
local maxScore = 10
local responseTime = 2
local scoreSide = "right"

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

    if score < maxScore then
        EventLoop.queue("simon-says:stop")
    end
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
    Utils.writeStartupFile("simon-says client")
    local service = Rpc.nearest(SimonSaysService)
    local isPlaying = false

    while true do
        EventLoop.pull("redstone")

        if redstone.getInput("top") and not isPlaying then
            service.playerStarted()
            isPlaying = true
        elseif not redstone.getInput("top") and isPlaying then
            service.playerExited()
            isPlaying = false
        end

        for side, sound in pairs(sounds) do
            if redstone.getInput(side) then
                speaker.playSound(sound, 3)

                if isPlaying then
                    service.playedSound(sound)
                end

                os.sleep(1)
                break
            end
        end
    end
end

---@param nextScore integer
local function setScore(nextScore)
    score = math.max(0, math.min(nextScore, maxScore))
    print(string.format("[score] %d/%d", score, maxScore))
    redstone.setAnalogOutput(scoreSide, score)
end

local function game()
    local speaker = peripheral.find("speaker")

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
            os.sleep(1)
            setScore(score + 1)

            if score < maxScore then
                speaker.playSound("entity.player.levelup", 1)
            end
        else
            os.sleep(1)
            -- [todo] setting to 0 is too harsh - maybe just reduce by 2-3
            -- [idea] maybe the further you are the more you lose? could do the same in target-practice
            setScore(0)
            speaker.playSound("block.lava.extinguish", 1)
        end

        if score < maxScore then
            os.sleep(3)
        end

        playedSounds = {}
    end
end

local function abort()
    setScore(0)
end

local function showWonAnimation()
    for _ = 1, 3 do
        redstone.setOutput(scoreSide, false)
        os.sleep(.5)
        redstone.setOutput(scoreSide, true)
        os.sleep(.5)
    end
end

local function win()
    speaker.playSound("ui.toast.challenge_complete", 3)
    os.sleep(.5)
    showWonAnimation()
    print("[success] good job!")
    redstone.setOutput("bottom", true)
    Utils.waitForUserToHitEnter("(hit enter to close door and restart)")
end

local function server()
    Utils.writeStartupFile("simon-says")
    local monitor = peripheral.find("monitor")

    if monitor then
        term.redirect(monitor)
    end

    setScore(0)
    print("[prompt] how many players?")
    requiredPlayers = EventLoop.pullInteger(1, 4)
    print("[players] set to", requiredPlayers)

    print("[prompt] how long to respond? (2 - 5)")
    responseTime = EventLoop.pullInteger(2, 5)
    print("[responseTime] set to", responseTime)

    EventLoop.run(function()
        Rpc.host(SimonSaysService)
    end, function()
        while true do
            redstone.setOutput("bottom", false)
            print("[waiting] for players to start the game")
            EventLoop.pull("simon-says:start")
            print("[start] get ready!")
            setScore(0)

            if EventLoop.runUntil("simon-says:stop", function()
                game()
            end) then
                abort()
            else
                win()
            end
        end
    end)
end

EventLoop.run(function()
    RemoteService.run({"simon-says"})
end, function()
    if isClient then
        client()
    else
        server()
    end
end)
