local Utils = require "utils"
local EventLoop = require "event-loop"

---@class SubwayStation
---@field id string

---@class SubwayTrack
---@field stationId string
---@field targetStationId string
---@field signal number

---@type integer|nil
local switchedTrackSignal = nil
---@type integer|nil
local trackSwitchTimerId = nil
local trackSwitchDuration = 7

local function flickerGate()
    redstone.setOutput("top", true)
    os.sleep(1)
    redstone.setOutput("top", false)
end

---@param signal integer
local function switchTrack(signal)
    local side = "left"

    if turtle then
        side = "right"
    end

    redstone.setOutput(side, true)
    redstone.setAnalogOutput("bottom", signal)

    while true do
        local _, timerId = EventLoop.pull("timer")

        if timerId == trackSwitchTimerId then
            break
        end
    end

    redstone.setOutput(side, false)
    redstone.setOutput("bottom", false)
end

---@class SubwayService : Service
---@field id string
local SubwayService = {name = "subway"}

---@return SubwayTrack[]
function SubwayService.getTracks()
    ---@type SubwayTrack[]
    local tracks = Utils.readJson("subway-tracks.json")

    return Utils.filter(tracks, function(item)
        return item.stationId == SubwayService.id
    end)
end

---@param signal integer
---@return SubwayTrack?, integer?
function SubwayService.getTrack(signal)
    return Utils.find(SubwayService.getTracks(), function(item)
        return item.signal == signal
    end)
end

---@param signal integer
---@return boolean
function SubwayService.readyToDispatchToTrack(signal)
    return switchedTrackSignal == nil or signal == switchedTrackSignal
end

---@param signal integer
---@return boolean
function SubwayService.dispatchToTrack(signal)
    if signal == switchedTrackSignal then
        flickerGate()
        os.cancelTimer(trackSwitchTimerId)
        trackSwitchTimerId = os.startTimer(trackSwitchDuration)
        return true
    elseif switchedTrackSignal == nil then
        trackSwitchTimerId = os.startTimer(trackSwitchDuration)
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

return SubwayService
