local Location = { }

--- <summary>
--- </summary>
--- <returns type="Components.Location"></returns>
function Location.new(computer)
    local instance = Components.Component.new(computer, "Location")

    setmetatable(Location, { __index = Components.Component })
    setmetatable(instance, { __index = Location })

    if (computer:isTurtle()) then
        instance:addDependency("Networking")
        instance:addDependency("Squirtle.Equipment")
        instance:addDependency("Squirtle.Fueling")
    end

    instance:ctor()

    return instance
end

function Location:ctor()
    self._cachedLocation = nil
    self._cachedOrientation = nil
end

--- <summary></summary>
--- <returns type="Components.Network"></returns>
function Location:getNetwork()
    return self:base():getDependency("Networking")
end

--- <summary></summary>
--- <returns type="Components.Squirtle.Equipment"></returns>
function Location:getEquipment()
    return self:base():getDependency("Squirtle.Equipment")
end

--- <summary></summary>
--- <returns type="Components.Squirtle.Fueling"></returns>
function Location:getFuel()
    return self:base():getDependency("Squirtle.Fueling")
end

--- <summary>instance: (Location)</summary>
--- <returns type="Components.Location"></returns>
function Location.cast(instance)
    return instance
end

--- <summary>Helper for BabeLua autocomplete</summary>
--- <returns type="Components.Component"></returns>
function Location:base()
    return self
end

--- <summary>Helper to call base class functions</summary>
--- <returns type="Components.Component"></returns>
function Location.super()
    return Components.Component
end

function Location:load()
    Location.super().load(self)

    if (self:base():getComputer():isComputer()) then
        local data = self:base():loadTable("data")
        self._cachedLocation = vector.new(data.location.x, data.location.y, data.location.z)
        self._cachedOrientation = data.orientation
    elseif (self:base():getComputer():isTurtle()) then
        self._cachedOrientation = self:orientate()
        self._cachedLocation = self:getLiveLocation()
        local squirtle = System.Squirtle.cast(self:base():getComputer())

        squirtle:on("turnLeft", function()
            self._cachedOrientation = self._cachedOrientation - 1
            self._cachedOrientation = self._cachedOrientation % 4
        end )

        squirtle:on("turnRight", function()
            self._cachedOrientation = self._cachedOrientation + 1
            self._cachedOrientation = self._cachedOrientation % 4
        end )

        local updateLocation = function(side)
            local orientation = self:sideToOrientation(side)
            local delta = ORIENTATIONS.Deltas[orientation]

            self._cachedLocation = self._cachedLocation + delta
        end

        squirtle:on("forward", function() updateLocation(FRONT) end)
        squirtle:on("back", function() updateLocation(BACK) end)
        squirtle:on("up", function() updateLocation(TOP) end)
        squirtle:on("down", function() updateLocation(BOTTOM) end)
    elseif (self:base():getComputer():isPocket()) then
        self._cachedOrientation = SOUTH
    end

    print(self._cachedLocation:tostring() .. " @ " .. self._cachedOrientation)
end

function Location:save()
    if (self:base():getComputer():isComputer()) then
        local t = { location = self._cachedLocation, orientation = self._cachedOrientation }
        self:base():saveTable("data", t)
    end
end

--function Location:install(installWizard)
--    if (not self:base():getComputer():isComputer()) then return nil end

--    installWizard = UI.ConsoleUI.cast(installWizard)

--    local location = self:tryGetLiveLocation()
--    local x, y, z

--    if (location == nil) then
--        x = installWizard:getInt("X?")
--        y = installWizard:getInt("Y?")
--        z = installWizard:getInt("Z?")
--    else
--        x = location.x
--        y = location.y
--        z = location.z
--    end

--    self._cachedOrientation = installWizard:getInt("Current Orientation?", 0, 3)
--    self._cachedLocation = vector.new(x, y, z)
--    self:save()
--end

--function Location:isInstalled()
--    if (self:base():getComputer():isComputer()) then
--        return self:base():tableExists("data")
--    else
--        return true
--    end
--end

function Location:getLocation()
    if (self:base():getComputer():isPocket()) then
        return self:getLiveLocation()
    end

    return self._cachedLocation
end

function Location:getOrientation()
    return self._cachedOrientation
end

function Location:sideToOrientation(side)
    if (side == TOP) then return UP end
    if (side == BOTTOM) then return DOWN end

    return(self:getOrientation() + side) % 4
end

function Location:orientate()
    if (not self:base():getComputer():isTurtle()) then
        return self:getOrientation()
    else
        local eq = self:getEquipment()
        local compassId = "minecraft:compass"

        if (eq:couldOrIsEquipped(compassId)) then
            local compass = eq:equip(compassId)
            return _G[compass.getFacing():upper()]
        else
            local location = self:getLiveLocation()
            local fuel = self:getFuel()

            for i = 0, 3 do
                fuel:refuel(2)
                if (turtle.forward()) then
                    local newLocation = self:getLiveLocation()
                    local orientation = nil

                    turtle.back()

                    if (newLocation.x > location.x) then orientation = EAST end
                    if (newLocation.x < location.x) then orientation = WEST end
                    if (newLocation.z > location.z) then orientation = SOUTH end
                    if (newLocation.z < location.z) then orientation = NORTH end

                    if (orientation) then
                        if (i > 2) then
                            orientation =(orientation + 1) % 4
                            turtle.turnRight()
                        else
                            for e = 1, i do
                                orientation =(orientation - 1) % 4
                                turtle.turnLeft()
                            end
                        end

                        return orientation
                    end
                end

                turtle.turnRight()
            end

            error("Turtle is caged in")
        end
    end
end

function Location:getLiveLocation()
    local location = self:tryGetLiveLocation()

    if (location == nil) then
        error("Location:getLiveLocation(): GPS dead")
    end

    return location
end

function Location:tryGetLiveLocation()
    local x, y, z = gps.locate(1)

    if (not x) then return nil end

    if (x < 0) then x = math.floor(x) else x = math.ceil(x) end
    if (z < 0) then z = math.floor(z) else z = math.ceil(z) end

    y = math.ceil(y)

    if (pocket) then
        y = y - 2
    end

    return vector.new(x, y, z)
end

function Location:getHorizontalChunkOrigin()
    local loc = self:getLocation()
    local relativeX = loc.x % 16
    local relativeZ = loc.z % 16

    return (vector.new(relativeX, 0, relativeZ) * -1) + self:getLocation()
end

function Location:deltaToHorizontalChunkCenter()
    local loc = self:getLocation()
    local relativeX = loc.x % 16
    local relativeZ = loc.z % 16

    return vector.new(7 - relativeX, 0, 7 - relativeZ)
end

if (Components == nil) then Components = { } end
Components.Location = Location