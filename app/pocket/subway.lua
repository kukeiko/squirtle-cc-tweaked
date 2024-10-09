package.path = package.path .. ";/?.lua"

local Utils = require "lib.common.utils"
local EventLoop = require "lib.common.event-loop"
local Rpc = require "lib.common.rpc"
local DatabaseService = require "lib.common.database-service"
local SubwayService = require "lib.features.subway-service"
local SearchableList = require "lib.ui.searchable-list"

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
---@param start SubwayStation
---@param goal SubwayStation
---@return boolean|SubwayStation[]
local function findPath(stations, start, goal)
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
            -- [todo] i don't think this is correct - we should visit all stations first to ensure the shortest path
            return getPath(previous, start, goal)
        end

        unvisited[nextStation.id] = nil

        local nextTracks = Utils.filter(nextStation.tracks, function(track)
            return unvisited[track.to] ~= nil
        end)

        for _, nextTrack in pairs(nextTracks) do
            local distance = distances[nextStation.id] + (nextTrack.duration or 0)

            if distance < distances[nextTrack.to] then
                distances[nextTrack.to] = distance
                previous[nextTrack.to] = nextStation
            end
        end
    end
end

---@param databaseService DatabaseService|RpcClient
---@param allStations? boolean
---@return string?
local function promptUserToPickGoal(databaseService, allStations)
    allStations = allStations or false
    local stations = databaseService.getSubwayStations()

    if not allStations then
        stations = Utils.filter(databaseService.getSubwayStations(), function(station)
            return station.type == "endpoint"
        end)
    end

    local options = Utils.map(stations, function(endpoint)
        ---@type SearchableListOption
        local option = {id = endpoint.id, name = endpoint.label or endpoint.name}

        return option
    end)

    table.sort(options, function(a, b)
        return a.name < b.name
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
    print("[subway v2.2.0] booting...")

    while true do
        local databaseService = Rpc.nearest(DatabaseService)

        if databaseService then
            DatabaseService.setSubwayStations(databaseService.getSubwayStations())
        else
            databaseService = DatabaseService
        end

        ---@type string?
        local goalId = args[1] or promptUserToPickGoal(databaseService)

        if not goalId then
            return
        end

        if goalId == "all" then
            goalId = promptUserToPickGoal(databaseService, true)
        end

        local stations = databaseService.getSubwayStations()

        local goal = Utils.find(stations, function(station)
            return station.id == goalId
        end)

        if not goal then
            error("no station w/ id '" .. goalId .. "' found")
        end

        print("[wait] for nearby station")
        ---@type string|nil
        local previousStation = nil
        ---@type integer|nil
        local resetPreviousStationTimerId = nil

        EventLoop.run(function()
            EventLoop.runUntil("subway:stop", function()
                while true do
                    local _, timerId = EventLoop.pull("timer")

                    if timerId == resetPreviousStationTimerId then
                        previousStation = nil
                    end
                end
            end)
        end, function()
            ---@type SubwayTrack
            local currentTrack = nil
            local previousStationTime = 0

            while true do
                local client = Rpc.nearest(SubwayService)

                if client and (previousStation == nil or client.host ~= previousStation) then
                    if currentTrack ~= nil then
                        local newDuration = math.floor((os.epoch("utc") - previousStationTime) / 1000)

                        if currentTrack.duration == nil or math.abs(newDuration - currentTrack.duration) > 1 then
                            print(string.format("[duration] updated to %ds", newDuration))
                            currentTrack.duration = newDuration
                            DatabaseService.setSubwayStations(stations)
                        end
                    end

                    previousStation = client.host
                    previousStationTime = os.epoch("utc")

                    if resetPreviousStationTimerId then
                        os.cancelTimer(resetPreviousStationTimerId)
                    end

                    resetPreviousStationTimerId = os.startTimer(10)

                    local station = Utils.find(stations, function(station)
                        return station.id == client.host
                    end)

                    if not station then
                        error(string.format("found station %s, but I did not find it in my database", client.host))
                    end

                    print("[found]", station.name)

                    local startId = station.id

                    if startId == goalId then
                        print("[done] enjoy your stay!")
                        os.sleep(3)
                        break
                    end

                    local path = findPath(stations, station, goal)

                    if not path or #path < 2 then
                        error("no path towards '" .. goal.name .. "' found :(")
                    end

                    local nextStation = path[2]
                    local track = Utils.find(station.tracks, function(item)
                        return item.to == nextStation.id
                    end)

                    if not track then
                        error("no track towards " .. nextStation.name .. " found")
                    end

                    currentTrack = track
                    print("[switch] to " .. nextStation.name)

                    local printedBusy = false

                    while not client.switchTrack(track.signal) do
                        if not printedBusy then
                            print("[wait] station is busy")
                            printedBusy = true
                        end

                        os.sleep(1)
                    end

                    if nextStation.type == "endpoint" then
                        print("[done] enjoy your stay!")
                        os.sleep(3)
                        break
                    end

                    print("[wait] for nearby station")

                    if currentTrack.duration then
                        print(string.format("[eta] %ds", currentTrack.duration))
                    end
                end
            end

            EventLoop.queue("subway:stop")
        end)
    end
end

main(arg)
