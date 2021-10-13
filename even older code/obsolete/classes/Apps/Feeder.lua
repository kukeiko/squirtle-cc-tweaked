local Feeder = { }

--- <summary>
--- </summary>
--- <returns type="Apps.Feeder"></returns>
function Feeder.new()
    local instance = { }
    setmetatable(instance, { __index = Feeder })
    instance:ctor()

    return instance
end

function Feeder:ctor()
    
end

function Feeder:run()
    MessagePump.run()

    local squirtle = System.Squirtle.new()
    local movement = Components.Squirtle.MovementComponent.cast(squirtle:base():installAndLoadComponent("Squirtle.Movement"))
    local feeder = Components.Squirtle.FeederComponent.cast(squirtle:base():installAndLoadComponent("Squirtle.Feeder"))
    local inv = Components.Squirtle.InventoryComponent.cast(squirtle:base():installAndLoadComponent("Squirtle.Inventory"))
    local ui = UI.ConsoleUI.new()

    local wheatId = "minecraft:wheat"
    local pathLength = ui:getInt("Path length?")

    local feedRoutine = function()
        for i = 1, pathLength do
            feeder:feed()
            movement:moveAggressive(FRONT)
        end

        movement:turn(LEFT, 2)
    end

    while (true) do
        local wheatCount = inv:getTotalItemQuantity(wheatId)

        if (wheatCount == 0) then
            print("No more wheat - waiting for more...")

            while (true) do
                MessagePump.pull("turtle_inventory")
                wheatCount = inv:getTotalItemQuantity(wheatId)
                if (wheatCount > 0) then
                    print("Found wheat! Starting in 3 seconds")
                    os.sleep(3)
                end
            end
        end

        print("Feeding...")
        feedRoutine()
        print("Waiting 6 minutes...")
        os.sleep(360)
    end
end

if (Apps == nil) then Apps = { } end
Apps.Feeder = Feeder