local EventLoop = require "event-loop"
local Side = require "elements.side"

---@type integer|nil
local switchedTrackSignal = nil
---@type integer|nil
local trackSwitchTimerId = nil

local function flickerGate()
    redstone.setOutput("top", true)
    os.sleep(1)
    redstone.setOutput("top", false)
end

---@class SubwayService : Service
---@field lockAnalogSide? string
---@field signalDuration number
---@field maxDistance number
local SubwayService = {name = "subway", signalDuration = 7, maxDistance = 5}

local function waitForSwitchTrackTimer()
    while true do
        local _, timerId = EventLoop.pull("timer")

        if timerId == trackSwitchTimerId then
            break
        end
    end
end

local function startSwitchTrackTimer()
    if trackSwitchTimerId then
        os.cancelTimer(trackSwitchTimerId)
    end

    trackSwitchTimerId = os.startTimer(SubwayService.signalDuration or 7)
end

---@param signal integer
local function switchTrack(signal)
    local lockAnalogSide = SubwayService.lockAnalogSide

    if lockAnalogSide and turtle then
        lockAnalogSide = Side.rotateAround(lockAnalogSide)
    end

    if lockAnalogSide then
        redstone.setOutput(lockAnalogSide, true)
    end

    redstone.setAnalogOutput("bottom", signal)
    startSwitchTrackTimer()
    waitForSwitchTrackTimer()

    if lockAnalogSide then
        redstone.setOutput(lockAnalogSide, false)
    end

    redstone.setOutput("bottom", false)
end

---@param signal integer
---@return boolean
function SubwayService.switchTrack(signal)
    if signal == switchedTrackSignal then
        flickerGate()
        startSwitchTrackTimer()
        waitForSwitchTrackTimer()

        return true
    elseif switchedTrackSignal == nil then
        switchedTrackSignal = signal

        EventLoop.run(flickerGate, function()
            switchTrack(signal)
            switchedTrackSignal = nil
        end)

        return true
    else
        return false
    end
end

---@return number
function SubwayService.getMaxDistance()
    return SubwayService.maxDistance
end

return SubwayService
