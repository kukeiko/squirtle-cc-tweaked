package.path = package.path .. ";/lib/?.lua"

local Utils = require "utils"
local Rpc = require "rpc"
local DatabaseService = require "services.database-service"
local SubwayService = require "services.subway-service"
local SearchableList = require "ui.searchable-list"

local pseudoInfinity = 64e10

---@param unvisited table<string, SubwayStation>
---@param distances table<string, number>
---@return SubwayStation?
local function nextToVisit(unvisited, distances)
    local best = nil

    for _, station in pairs(unvisited) do
        if best == nil or (distances[station.id] ~= nil and distances[station.id] <= distances[best.id]) then
            best = station
        end
    end

    return best
end

---@param previous SubwayStation[]
---@param start SubwayStation
---@param goal SubwayStation
---@return false|SubwayStation[]
local function getPath(previous, start, goal)
    ---@type SubwayStation[]
    local path = {}
    local nextStation = goal

    if previous[goal.id] or start.id == goal.id then
        while nextStation do
            table.insert(path, nextStation)
            nextStation = previous[nextStation.id]
        end

        return Utils.reverse(path)
    else
        return false
    end
end

---@param stations SubwayStation[]
---@param tracks SubwayTrack[]
---@param start SubwayStation
---@param goal SubwayStation
local function findPath(stations, tracks, start, goal)
    ---@type table<string, number>
    local distances = {}
    ---@type table<string, SubwayStation>
    local unvisited = {}

    for _, station in pairs(stations) do
        unvisited[station.id] = station
        distances[station.id] = pseudoInfinity
    end

    distances[start.id] = 0

    ---@type table<string, SubwayStation>
    local previous = {}

    while true do
        local nextStation = nextToVisit(unvisited, distances)

        if not nextStation then
            return false
        elseif nextStation.id == goal.id then
            return getPath(previous, start, goal)
        end

        unvisited[nextStation.id] = nil

        local nextTracks = Utils.filter(tracks, function(track)
            return track.stationId == nextStation.id and unvisited[track.targetStationId] ~= nil
        end)

        for _, nextTrack in pairs(nextTracks) do
            local distance = distances[nextStation.id] + (nextTrack.duration or 60)

            if distance < distances[nextTrack.targetStationId] then
                distances[nextTrack.targetStationId] = distance
                previous[nextTrack.targetStationId] = nextStation
            end
        end
    end
end

---@param allStations? boolean
---@return string?
local function promptUserToPickGoal(allStations)
    allStations = allStations or false
    local stations = DatabaseService.getSubwayStations()

    if not allStations then
        stations = Utils.filter(DatabaseService.getSubwayStations(), function(station)
            return station.type == "endpoint"
        end)
    end

    local options = Utils.map(stations, function(endpoint)
        ---@type SearchableListOption
        local option = {id = endpoint.id, name = endpoint.label or endpoint.name}

        return option
    end)

    local titles = {
        "Where we goin' lad?",
        "Where to boss?",
        "Which one shall it be Sir?",
        "YARR where be booty at?",
        "Please pick a Station",
        "Please pick a Station",
        "Please pick a Station"
    }

    local list = SearchableList.new(options, titles[math.random(#titles)])
    local selected = list:run()

    if selected then
        return selected.id
    end
end

local function main(args)
    print("[subway v1.0.0] booting...")

    ---@type string?
    local goalId = args[1] or promptUserToPickGoal()

    if not goalId then
        return
    end

    if goalId == "all" then
        goalId = promptUserToPickGoal(true)
    end

    local stations = DatabaseService.getSubwayStations()
    local tracks = DatabaseService.getSubwayTracks()

    local goal = Utils.find(stations, function(station)
        return station.id == goalId
    end)

    if not goal then
        error("no station w/ id '" .. goalId .. "' found")
    end

    print("[wait] for nearby station")
    while true do
        local client, distance = Rpc.nearest(SubwayService)

        if client and distance <= client.getMaxDistance() then
            local station = Utils.find(stations, function(station)
                return station.id == client.host
            end)

            if not station then
                error("reached station '" .. client.host .. "', but I did not find it in my database")
            end

            print("[reached]", station.name)

            local startId = client.host

            if startId == goalId then
                print("[done] enjoy your stay!")
                break
            end

            local path = findPath(stations, tracks, station, goal)

            if path and #path > 1 then
                local nextStation = path[2]
                local track = Utils.find(tracks, function(item)
                    return item.stationId == startId and item.targetStationId == nextStation.id
                end)

                if not track then
                    error("no track going towards " .. nextStation.name .. " found")
                end

                print("[switch] " .. nextStation.name)

                local printedBusy = false

                while not client.switchTrack(track.signal) do
                    if not printedBusy then
                        print("[wait] station is busy")
                        printedBusy = true
                    end

                    os.sleep(1)
                    -- [todo] what if station is a switch that was busy and we are now no longer in range of it?
                    -- (i.e. we passed it and need to route to goal somehow else)
                end

                if nextStation.type == "endpoint" then
                    print("[reached]", nextStation.name)
                    print("[done] enjoy your stay!")
                    break
                end

                print("[wait] for nearby station")
            else
                error("no path towards '" .. goal.name .. "' found :(")
            end
        end
    end
end

main(arg)
