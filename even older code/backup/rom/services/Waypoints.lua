--- Provides access points in the world.
-- Uses port 64 by default.
-- @module Services.Waypoints

local Waypoints = {
    port = 64
}

--- <summary></summary>
--- <returns type="Waypoints"></returns>
function Waypoints.new(unit)
    local instance = { }
    setmetatable(instance, { __index = Waypoints })
    instance:ctor(unit)

    return instance
end

--- <summary>
--- </summary>
--- <returns type="Waypoints"></returns>
function Waypoints.nearest(adapter)
    local nearest = Unity.Client.nearest("ping", adapter, Waypoints.port)
    return Unity.ClientProxy.new(adapter, nearest:getSourceAddress(), Waypoints.port)
end

function Waypoints:ctor(unit)
    self._unit = Squirtle.Unit.as(unit)
    self._server = nil
end

function Waypoints:getName()
    return "Waypoints"
end

function Waypoints:run()
    self:load()

    local network = Components.Networking.as(self._unit:loadComponent("Networking"))
    self._server = Unity.Server.new(network:getWirelessAdapter(), self.port)
    self._server:wrap(self, {
        "ping", false,
        "all",
        "count",
        "create",
        "delete"
    } )
end

function Waypoints:stop()
    self._server:close()
end

function Waypoints:config(buffer)
    local sel = Kevlar.Sync.Select.new(buffer)

    sel:addOption("Create a waypoint", function() self:configCreateWaypoint(buffer) end)
    if (self:count() > 0) then
        sel:addOption("Delete a waypoint", function() self:configDeleteWaypoint(buffer) end)
    end
    sel:addOption("Back", function() return true end)

    if (sel:run()() ~= true) then
        self:config(buffer)
    end
end

function Waypoints:configCreateWaypoint(buffer)
    local wizard = Kevlar.Sync.Wizard.new(buffer)
    local name = wizard:getString("Name")
    local location = nil

    if (wizard:getBool("At current location?")) then
        local loc = Components.Location.as(self._unit:loadComponent("Location"))
        location = loc:getLocation()
    else
        location = wizard:getVector("Location")
    end

    self:create(Scout.Waypoint.new(name, location))
end

function Waypoints:configDeleteWaypoint(buffer)
    local wp = self:configSelectWaypoint(buffer)
    if(wp == nil) then return end

    self:delete(wp)
end

function Waypoints:configSelectWaypoint(buffer)
    local selection = Kevlar.Sync.Select.new(buffer)
    local wps = self:all()

    for i = 1, #wps do
        local wp = Scout.Waypoint.as(wps[i])
        selection:addOption(wp:toString(), wp)
    end

    return selection:run()
end

function Waypoints:load()
    local path = "/cache/services/waypoints"
    self._waypoints = { }

    if (Disk.exists(path)) then
        local data = Disk.loadTable(path)

        for i = 1, #data do
            table.insert(self._waypoints, Scout.Waypoint.cast(data[i]))
        end

        Log.debug("[Services.Waypoints] loaded " .. #data .. " waypoints from " .. path)
    end
end

function Waypoints:save()
    Disk.saveTable("/cache/services/waypoints", self._waypoints)
end

function Waypoints:ping()
    return "pong"
end

function Waypoints:all()
    return self._waypoints
end

function Waypoints:count()
    return #self._waypoints
end

function Waypoints:create(waypoint)
    table.insert(self._waypoints, Scout.Waypoint.cast(waypoint))
    self:save()
end

function Waypoints:delete(waypoint)
    if (waypoint == nil) then error("trying to delete nil") end
    waypoint = Scout.Waypoint.cast(waypoint)

    for i = 1, #self._waypoints do
        if (self._waypoints[i]:equals(waypoint)) then
            table.remove(self._waypoints, i)
            break
        end
    end

    self:save()
end

if (Services == nil) then Services = { } end
Services.Waypoints = Waypoints