local EventLoop = require "lib.common.event-loop"
local Side = require "lib.common.side"

---@type integer|nil
local switchedTrackSignal = nil

local timers = {
    ---@type integer|nil
    closeGate = nil,
    ---@type integer|nil
    resetSignal = nil
}

---@class SubwayService : Service
---@field isHub boolean
---@field signalDuration number
---@field lockAnalogSide? string
local SubwayService = {name = "subway", signalDuration = 7, maxDistance = 5, isHub = false}

local function lockHubAnalog()
    local lockAnalogSide = SubwayService.lockAnalogSide

    if lockAnalogSide and turtle then
        lockAnalogSide = Side.rotate180(lockAnalogSide)
    end

    if lockAnalogSide then
        redstone.setOutput(lockAnalogSide, true)
    end
end

local function unlockHubAnalog()
    local lockAnalogSide = SubwayService.lockAnalogSide

    if lockAnalogSide and turtle then
        lockAnalogSide = Side.rotate180(lockAnalogSide)
    end

    if lockAnalogSide then
        redstone.setOutput(lockAnalogSide, false)
    end
end

---@return number
function SubwayService.getMaxDistance()
    return SubwayService.maxDistance
end

local function openHubGate()
    redstone.setOutput("top", true)

    if timers.closeGate then
        os.cancelTimer(timers.closeGate)
    end

    timers.closeGate = os.startTimer(1)
end

local function closeGateWatcher()
    while true do
        local _, timerId = EventLoop.pull("timer")

        if timerId and timers.closeGate == timerId then
            redstone.setOutput("top", false)
        end
    end
end

local function resetSignalWatcher()
    while true do
        local _, timerId = EventLoop.pull("timer")

        if timerId and timers.resetSignal == timerId then
            switchedTrackSignal = nil
            redstone.setAnalogOutput("bottom", 0)
            unlockHubAnalog()
        end
    end
end

---@param signal integer
---@return boolean
function SubwayService.switchTrack(signal)
    if not SubwayService.isHub then
        redstone.setAnalogOutput("bottom", signal)
        return true
    end

    if switchedTrackSignal ~= nil and signal ~= switchedTrackSignal then
        return false
    end

    switchedTrackSignal = signal
    openHubGate()
    lockHubAnalog()
    redstone.setAnalogOutput("bottom", signal)

    if timers.resetSignal then
        os.cancelTimer(timers.resetSignal)
    end

    timers.resetSignal = os.startTimer(SubwayService.signalDuration)

    return true
end

function SubwayService.start()
    SubwayService.isHub = true
    EventLoop.run(closeGateWatcher, resetSignalWatcher)
end

return SubwayService
