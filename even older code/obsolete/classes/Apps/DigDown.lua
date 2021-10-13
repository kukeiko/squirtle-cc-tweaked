local DigDown = { }

--- <summary>
--- </summary>
--- <returns type="DigDown"></returns>
function DigDown.new()
    local instance = { }
    setmetatable(instance, { __index = DigDown })
    instance:ctor()

    return instance
end

function DigDown:ctor()
end

function DigDown:run()
    local squirtle = System.Squirtle.new()
    local pickaxe = Components.Squirtle.PickaxeComponent.cast(squirtle:base():installAndLoadComponent("Squirtle.Pickaxe"))
    local movement = Components.Squirtle.MovementComponent.cast(squirtle:base():installAndLoadComponent("Squirtle.Movement"))
    local fuel = Components.Squirtle.FuelComponent.cast(squirtle:base():installAndLoadComponent("Squirtle.Fuel"))
    local location = Components.LocationComponent.cast(squirtle:base():installAndLoadComponent("Location"))

    local ui = UI.ConsoleUI.new()
    
    local times
    local untilBedrock = ui:getBool("Until bedrock?")

    if(untilBedrock) then
        local y = location:getLocation().y
        times = 1000 --y - 1
    else
        times = ui:getInt("How many blocks?")
    end

    local doReturn = ui:getBool("Come back?")
    local requiredFuel = times

    if (doReturn) then
        requiredFuel = requiredFuel * 2
    end

    fuel:refuel(requiredFuel)

    local moved = 0

    for i = 1, times do
        -- bedrock hit, go up
        if(not pcall(function() pickaxe:dig(DOWN) end)) then
            break
        end

        if(i ~= times) then
            movement:moveAggressive(DOWN, 1)
            moved = moved + 1
        end
    end

    if (doReturn) then
        movement:moveAggressive(UP, moved)
    end
end

if (Apps == nil) then Apps = { } end
Apps.DigDown = DigDown