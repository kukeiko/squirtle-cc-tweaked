local DigLine = { }

--- <summary>
--- </summary>
--- <returns type="DigLine"></returns>
function DigLine.new()
    local instance = { }
    setmetatable(instance, { __index = DigLine })
    instance:ctor()

    return instance
end

function DigLine:ctor()
end

function DigLine:run()
    local squirtle = System.Squirtle.new()
    local pickaxe = Components.Squirtle.PickaxeComponent.cast(squirtle:base():installAndLoadComponent("Squirtle.Pickaxe"))
    local movement = Components.Squirtle.MovementComponent.cast(squirtle:base():installAndLoadComponent("Squirtle.Movement"))
    local fuel = Components.Squirtle.FuelComponent.cast(squirtle:base():installAndLoadComponent("Squirtle.Fuel"))

    local ui = UI.ConsoleUI.new()
    local times = ui:getInt("How many blocks?")
    local doReturn = ui:getBool("Come back?")

    local requiredFuel = times
    if (doReturn) then
        requiredFuel = requiredFuel * 2
    end

    fuel:refuel(requiredFuel)

    for i = 1, times do
        pickaxe:dig()
        movement:moveAggressive(FRONT, 1)
        pickaxe:dig(UP)
    end

    if (doReturn) then
        movement:turn(LEFT, 2)
        movement:moveAggressive(FRONT, times)
        movement:turn(LEFT, 2)
    end
end

if (Apps == nil) then Apps = { } end
Apps.DigLine = DigLine