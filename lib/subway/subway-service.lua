local Utils = require "utils"
local EventLoop = require "event-loop"

---@class SubwayStation
---@field id string

---@class SubwayTrack
---@field stationId string
---@field targetStationId string
---@field signal number

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

    print("switching to track", signal)
    redstone.setOutput(side, true)
    redstone.setAnalogOutput("bottom", signal)
    os.sleep(7)
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
function SubwayService.dispatchToTrack(signal)
    EventLoop.run(flickerGate, function()
        switchTrack(signal)
    end)
end

return SubwayService
