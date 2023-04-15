local Utils = require "utils"
local Database = {}

---@return SubwayStation[]
function Database.getSubwayStations()
    return Utils.readJson("data/subway-stations.json")
end

---@param stationId? string
---@return SubwayTrack[]
function Database.getSubwayTracks(stationId)
    ---@type SubwayTrack[]
    local tracks = Utils.readJson("data/subway-tracks.json")

    if stationId == nil then
        return tracks
    end

    return Utils.filter(tracks, function(item)
        return item.stationId == stationId
    end)
end

---@param stationId string
---@param signal integer
---@return SubwayTrack?
function Database.getSubwayTrack(stationId, signal)
    local track = Utils.find(Database.getSubwayTracks(stationId), function(item)
        return item.signal == signal
    end)

    return track
end

return Database
