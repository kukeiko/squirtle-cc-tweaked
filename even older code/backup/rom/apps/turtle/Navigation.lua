local Navigation = { }

--- <summary></summary>
--- <returns type="Navigation"></returns>
function Navigation.new(unit)
    local instance = { }
    setmetatable(instance, { __index = Navigation })
    instance:ctor(unit)

    return instance
end

function Navigation:ctor(unit)
    self._turtle = Squirtle.Turtle.as(unit)
end

function Navigation:boot()
    self._navigation = Components.Navigation.get(self._turtle)
    self._location = Components.Location.get(self._turtle)
    self._network = Components.Networking.get(self._turtle)
    self._waypoints = Services.Waypoints.nearest(self._network:getWirelessAdapter())
    self._worldMap = Services.WorldMap.nearest(self._network:getWirelessAdapter())
    self._terminal = Kevlar.Terminal.new()
end

function Navigation:run()
    self:boot()

    local header = Kevlar.Header.new("Navigation", "-", self._terminal:sub(1, 1, "*", 2))
    header:draw()

    self:mainMenu(self._terminal:sub(1, 3, "*", "*"))
end

--- <summary></summary>
--- <returns type="Services.Waypoints"></returns>
function Navigation:getWaypointService()
    local success, response = pcall( function() return self._waypoints:ping() end)

    if (not success) then
        self._waypoints = Services.Waypoints.nearest(self._network:getWirelessAdapter())
    end

    return self._waypoints
end

--- <summary></summary>
--- <returns type="Services.WorldMap"></returns>
function Navigation:getWorldMap()
    local success, response = pcall( function() return self._worldMap:ping() end)

    if (not success) then
        self._worldMap = Services.WorldMap.nearest(self._network:getWirelessAdapter())
    end

    return self._worldMap
end

function Navigation:mainMenu(buffer)
    local menu = Kevlar.Sync.Select.new(buffer)
    local wps = self:getWaypointService()

    if (wps:count() > 0) then
        menu:addOption("Move to waypoint", function() self:moveToWaypoint(buffer) end)
    end

    menu:addOption("Create waypoint", function() self:createWaypoint(buffer) end)

    if (wps:count() > 0) then
        menu:addOption("Remove waypoint", function() self:removeWaypoint(buffer) end)
    end

    local chosen = menu:run()
    if (chosen == nil) then self:mainMenu(buffer) end
    chosen()
    self:mainMenu(buffer)
end

function Navigation:createWaypoint(buffer)
    local wizard = Kevlar.Sync.Wizard.new(buffer)
    local name = wizard:getString("Name")
    if(name == nil) then return end
    local location = nil

    if (wizard:getBool("At current location?")) then
        location = self._location:getLocation()
    else
        location = wizard:getVector("Location")
    end

    self:getWaypointService():create(Waypoint.new(location, name))
end

function Navigation:moveToWaypoint(buffer)
    buffer = Kevlar.IBuffer.as(buffer)

    local waypoint = self:selectWaypoint(buffer)
    if (waypoint == nil) then return end

    buffer:clear()
    buffer:write(1, 1, "Loading World ...")
    local world = self:getWorldMap():all()
    buffer:write(1, 2, "Navigating towards " .. waypoint:toString() .. " ...")

    self._navigation:navigateTo(waypoint:getLocation(), world)
    local sensor = Components.Sensor.as(self._turtle:loadComponent("Sensor"))
    self:getWorldMap():add(sensor:getWorld())
end

function Navigation:removeWaypoint(buffer)
    local wp = self:selectWaypoint(buffer)
    if (wp == nil) then return end
    self:getWaypointService():delete(wp)
end

function Navigation:selectWaypoint(buffer)
    local selection = Kevlar.Sync.Select.new(buffer)
    local wps = self:getWaypointService():all()

    for i = 1, #wps do
        local wp = Waypoint.fromData(wps[i])
        selection:addOption(wp:toString(), wp)
    end

    return selection:run()
end

if (Apps == nil) then Apps = { } end
Apps.Navigation = Navigation