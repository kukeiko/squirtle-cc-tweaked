local Depots = { }

function Depots.new(adapter, serverAddress, port)
    local instance = Unity.Client.new(adapter, serverAddress, port)
    setmetatable(instance, { __index = Depots })
    setmetatable(Depots, { __index = Unity.Client })

    return instance
end

--- <summary>
--- </summary>
--- <returns type="Clients.Depots"></returns>
function Depots.as(instance)
    return instance
end

--- <summary>
--- </summary>
--- <returns type="Unity.Client"></returns>
function Depots.super(instance)
    return instance
end

--- <summary>
--- </summary>
--- <returns type="Clients.Depots"></returns>
function Depots.nearest(adapter)
    local nearest = Unity.Client.nearest("ping", adapter, Services.Depots.port)
    return Depots.new(adapter, nearest:getSourceAddress(), Services.Depots.port)
end

function Depots:ping()
    return self:send("ping")
end

function Depots:refresh()
    local success, response = pcall(function() return self:ping()  end)
    
    if(not success) then
        local nearest = Unity.Client.nearest("ping", self:super():getAdapter(), Services.Depots.port)
        self:super():changeAddress(nearest:getSourceAddress())
    end

    return self
end

function Depots:all()
    local depots = Unity.Client.send(self, "all")

    for i = 1, #depots do
        depots[i] = Entities.Depot.cast(depots[i])
    end

    return depots
end

if(Clients == nil) then Clients = {} end
Clients.Depots = Depots