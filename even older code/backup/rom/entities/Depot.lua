local Depot = { }

--- <summary></summary>
--- <returns type="Entities.Depot"></returns>
function Depot.new(name, location)
    local instance = { }
    setmetatable(instance, { __index = Depot })

    instance:ctor(name, location)

    return instance
end

function Depot:ctor(name, location)
    self._name = name
    self._location = Squirtle.Vector.as(location)
end

--- <summary></summary>
--- <returns type="Entities.Depot></returns>
function Depot.as(instance)
    return instance
end

function Depot.cast(data)
    setmetatable(data, { __index = Depot })
    data._location = Squirtle.Vector.cast(data._location)
    return data
end

function Depot:getName()
    return self._name
end

--- <summary></summary>
--- <returns type="Squirtle.Vector"></returns>
function Depot:getLocation()
    return self._location
end

function Depot:toString()
    return self._name .. " @ (" .. self._location .. ")"
end

if (Entities == nil) then Entities = { } end
Entities.Depot = Depot