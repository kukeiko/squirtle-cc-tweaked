---@alias SubwayStationType "hub"|"endpoint"|"platform"|"switch"
---
---@class SubwayStation
---@field id string
---@field name string
---@field label? string
---@field type SubwayStationType
---
---@class SubwayTrack
---@field stationId string
---@field targetStationId string
---@field signal number
---@field duration? number
---