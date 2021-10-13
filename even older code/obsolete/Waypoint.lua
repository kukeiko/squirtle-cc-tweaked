--Waypoint = { }

----- <summary>
----- id: (string)
----- quantity: (number)
----- damage: (number)
----- </summary>
----- <returns type="Waypoint"></returns>
--function Waypoint.new(location, name)
--    local instance = { }
--    setmetatable(instance, { __index = Waypoint })
--    instance:ctor(location, name)

--    return instance
--end

----- <summary></summary>
----- <returns type="Waypoint"></returns>
--function Waypoint.fromData(t)
--    return Waypoint.new(vector.new(t.location.x, t.location.y, t.location.z), t.name)
--end

--function Waypoint:toData()
--    return { location = self._location, name = self._name }
--end

--function Waypoint:ctor(location, name)
--    self.location = location
--    self.name = name
--end

--function Waypoint:getName()
--    if (self.name == nil) then return "???" end
--    return self.name
--end

----- <summary></summary>
----- <returns type="vector"></returns>
--function Waypoint:getLocation() return self.location end

--function Waypoint:toString()
--    return self:getName() .. " @ (" .. self:getLocation():tostring() .. ")"
--end

--function Waypoint:equals(other)
--    return other.name == self.name
--    and vector.equals(other.location, self.location)
--end

----- <summary></summary>
----- <returns type="Waypoint"></returns>
--function Waypoint.cast(item) return item end