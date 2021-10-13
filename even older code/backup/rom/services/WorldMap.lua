--- Worldmap Network Service
-- @module Services.Worldmap

local WorldMap = {
    _port = 8
}

--- <summary>
--- </summary>
--- <returns type="WorldMap"></returns>
function WorldMap.new(unit)
    local instance = { }
    setmetatable(instance, { __index = WorldMap })

    instance:ctor(unit)

    return instance
end

--- <summary></summary>
--- <returns type="WorldMap"></returns>
function WorldMap.nearest(adapter)
    local nearest = Unity.Client.nearest("ping", adapter, WorldMap._port)
    return Unity.ClientProxy.new(adapter, nearest:getSourceAddress(), WorldMap._port)
end

function WorldMap:ctor(unit)
    if (unit == nil) then error("arg unit is nil") end
    self._unit = Squirtle.Unit.as(unit)
    self._server = nil
end

function WorldMap:run()
    self:load()

    local network = Components.Networking.as(self._unit:loadComponent("Networking"))
    self._server = Unity.Server.new(network:getWirelessAdapter(), self._port)
    self._server:wrap(self, {
        "ping", false,
        "all",
        "add"
    } )
end

function WorldMap:stop()
    self._server:close()
end

function WorldMap:config(buffer)
end

function WorldMap:load()
    local path = "/cache/services/worldmap"
    self._map = { }

    if (Disk.exists(path)) then
        local data = Disk.loadTable(path)

        for i = 1, #data do
            local v = vector.new(data[i].x, data[i].y, data[i].z)
            self._map[v:tostring()] = v
        end
    end
end

function WorldMap:save()
    Disk.saveTable("/cache/services/worldmap", self._map)
end

function WorldMap:ping()
    return "pong"
end

function WorldMap:all()
    return self._map
end

function WorldMap:add(points)
    for k, v in pairs(points) do
        local vec = vector.new(v.x, v.y, v.z)
        self._map[k] = v
    end
    self:save()
end

if (Services == nil) then Services = { } end
Services.WorldMap = WorldMap