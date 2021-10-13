local Depots = {
    port = 24
}

function Depots.new(unit)
    local instance = { }
    setmetatable(instance, { __index = Depots })

    instance:ctor(unit)

    return instance
end

function Depots:ctor(unit)
    self._tablet = Squirtle.Tablet.as(unit)
    self._depots = { }
    self._server = nil
end

function Depots:load()
    local path = "/cache/services/depots"
    self._depots = { }

    if (Disk.exists(path)) then
        local data = Disk.loadTable(path)

        for i = 1, #data do
            table.insert(self._depots, Entities.Depot.cast(data[i]))
        end

        Log.debug("[Services.Depots] loaded " .. #data .. " depots from " .. path)
    end
end

function Depots:save()
    Disk.saveTable("/cache/services/depots", self._depots)
end

function Depots:run()
    self:load()
    self._server = Unity.Server.new(self._tablet:getWirelessAdapter(), Depots.port)
    self._server:wrap(self, {
        "ping",false,
        "all"
    } )
end

function Depots:stop()
end

function Depots:config(buffer)
    buffer = Kevlar.IBuffer.as(buffer)

    local sel = Kevlar.Sync.Select.new(buffer)
    sel:addOption("Create a new depot", function() self:createDepot(buffer) end)

    if (#self._depots > 0) then
        --        sel:addOption("Edit a depot", function() end)
        sel:addOption("Delete a depot", function() self:deleteDepot(buffer) end)
    end

    local r = sel:run()
    if (r == nil) then return end

    r()
    self:config(buffer)
end

function Depots:createDepot(buffer)
    buffer = Kevlar.IBuffer.as(buffer)

    local wiz = Kevlar.Sync.Wizard.new(buffer)
    local name = wiz:getString("Name")
    if (name == nil) then return end

    buffer:clear()
    buffer:write(1, 1, "Position:")

    local sel = Kevlar.Sync.Select.new(buffer:sub(1, 2, "*", "*"))
    sel:addOption("Enter manually", function()
        return wiz:getVector("Squirtle.Vector")
    end )
    sel:addOption("I stand on top of it", function()
        return self._tablet:getLocation() + Squirtle.Vector.new(0, -1, 0)
    end )

    local r = sel:run()
    if (r == nil) then return end

    local pos = r()
    if (pos == nil) then return end

    self:create(Entities.Depot.new(name, pos))
end

function Depots:deleteDepot(buffer)
    local d = self:configSelectDepot(buffer)
    if (d == nil) then return end
    self:delete(d)
end

function Depots:configSelectDepot(buffer)
    local selection = Kevlar.Sync.Select.new(buffer)
    local depots = self:all()

    for i = 1, #depots do
        selection:addOption(depots[i]:toString(), depots[i])
    end

    return selection:run()
end

function Depots:ping()
    return "pong"
end

function Depots:all()
    return self._depots
end

function Depots:count()
    return #self._depots
end

function Depots:create(depot)
    table.insert(self._depots, Entities.Depot.cast(depot))
    self:save()
end

function Depots:delete(depot)
    if (depot == nil) then error("trying to delete nil") end
    depot = Entities.Depot.cast(depot)

    for i = 1, #self._depots do
        if (self._depots[i]:getName() == depot:getName()) then
            table.remove(self._depots, i)
            break
        end
    end

    self:save()
end

if (Services == nil) then Services = { } end
Services.Depots = Depots