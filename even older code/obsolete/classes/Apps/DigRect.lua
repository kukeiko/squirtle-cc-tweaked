local DigRect = { }

--- <summary>
--- </summary>
--- <returns type="DigRect"></returns>
function DigRect.new()
    local instance = { }
    setmetatable(instance, { __index = DigRect })
    instance:ctor()

    return instance
end

function DigRect:ctor()
end

function DigRect:run()
    local squirtle = System.Squirtle.new()
    local pickaxe = Components.Squirtle.Pickaxe.cast(squirtle:base():loadComponent("Squirtle.Pickaxe"))
    local movement = Components.Squirtle.Movement.cast(squirtle:base():loadComponent("Squirtle.Movement"))
    local fuel = Components.Squirtle.Fueling.cast(squirtle:base():loadComponent("Squirtle.Fueling"))

    local ui = UI.ConsoleUI.new()
    local times = ui:getInt("How many blocks?")
    local lines = ui:getInt("How many lines?")
    local moveLeft = ui:getBool("Move left?")
    local digUp = ui:getBool("Dig up?")
    local digDown = ui:getBool("Dig down?")

    local requiredFuel = times * lines

    if (doReturn) then
        requiredFuel = requiredFuel * 2
    end

    fuel:refuel(requiredFuel)

    local digRoutine = function()
        pickaxe:dig()

        movement:moveAggressive(FRONT, 1)

        if (digUp) then
            pickaxe:dig(UP)
        end

        if (digDown) then
            pickaxe:dig(DOWN)
        end
    end

    for i = 1, lines do
        local lineTimes = times

        self:cleanInventory()
        if (i > 1) then
            lineTimes = lineTimes - 1
        end

        for e = 1, lineTimes do
            digRoutine()

            if (e % 30 == 0) then
                self:cleanInventory()
            end
        end

        if (i < lines) then
            local turnDirection

            if (i % 2 == 0) then
                if (moveLeft) then
                    turnDirection = RIGHT
                else
                    turnDirection = LEFT
                end
            else
                if (moveLeft) then
                    turnDirection = LEFT
                else
                    turnDirection = RIGHT
                end
            end

            movement:turn(turnDirection)
            digRoutine()
            movement:turn(turnDirection)
        end
    end
end

function DigRect:cleanInventory()
    local squirtle = System.Squirtle.new()
    local inv = Components.Squirtle.Inventory.cast(squirtle:base():loadComponent("Squirtle.Inventory"))

    inv:condense()

    for i = 1, inv:numSlots() do
        local itemId = inv:getId(i)
        if (itemId) then
            itemId = itemId:lower()
            local keep = false

            if (string.match(itemId, "diamond")) then
                keep = true
            elseif (string.match(itemId, "ore")) then
                keep = true
            elseif (string.match(itemId, "lapis")) then
                keep = true
            elseif (string.match(itemId, "redstone")) then
                keep = true
            elseif (string.match(itemId, "emerald")) then
                keep = true
            elseif (string.match(itemId, "coal")) then
                keep = true
            end

            if (not keep) then
                inv:select(i)
                turtle.drop()
            end
        end
    end

    inv:condense()
end

if (Apps == nil) then Apps = { } end
Apps.DigRect = DigRect