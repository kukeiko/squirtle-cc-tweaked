local Test = { }

function Test.new(unit)
    local instance = { }
    setmetatable(instance, { __index = Test })
    instance:ctor(unit)

    return instance
end

function Test:ctor(unit)
    self._turtle = Squirtle.Turtle.as(unit)
end

function Test:run()
    local net = Components.Networking.get(self._turtle)
    local eq = Components.Equipment.get(self._turtle)

    while (true) do
        eq:equip("minecraft:diamond_pickaxe")
        local compass = eq:equip("minecraft:compass")
        compass.getFacing()
        turtle.turnLeft()
    end
end

if (Apps == nil) then Apps = { } end
Apps.Test = Test